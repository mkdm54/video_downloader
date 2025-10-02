import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeDownloader {
  final yt = YoutubeExplode();

  /// Meminta izin yang diperlukan untuk menyimpan media di Android.
  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;

    if (await Permission.videos.request().isGranted) return;
    if (await Permission.photos.request().isGranted) return;
    if (await Permission.storage.request().isGranted) return;

    throw Exception('Izin untuk menyimpan media ke galeri ditolak.');
  }

  /// Mengunduh video dari URL YouTube dan menyimpannya ke galeri.
  Future<void> downloadVideo({
    required String url,
    required void Function(double progress) onProgress,
    required void Function(String message) onError,
    required void Function(String filePath) onComplete,
  }) async {
    try {
      // 1) Request izin
      await requestPermission();

      // 2) Ambil info video
      final video = await yt.videos.get(url);
      debugPrint("🎬 Judul Video: ${video.title}");

      // 3) Ambil manifest
      final manifest = await yt.videos.streamsClient.getManifest(video.id);

      // 4) Path sementara
      final tempDir = await getTemporaryDirectory();
      final safeTitle = video.title
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), "_")
          .replaceAll(RegExp(r'\s+'), " ")
          .trim();
      final filePath = '${tempDir.path}/$safeTitle.mp4';
      final file = File(filePath);

      if (file.existsSync()) await file.delete();

      if (manifest.muxed.isNotEmpty) {
        // Muxed video+audio
        final streamInfo = manifest.muxed.withHighestBitrate();
        final stream = yt.videos.streamsClient.get(streamInfo);
        final output = file.openWrite();
        int downloaded = 0;
        final total = streamInfo.size.totalBytes;

        await for (final chunk in stream) {
          downloaded += chunk.length;
          output.add(chunk);
          if (total > 0) onProgress(downloaded / total);
        }

        await output.flush();
        await output.close();
        debugPrint("✅ Berhasil diunduh (muxed) ke: $filePath");
      } else {
        // Video & audio terpisah, gabungkan
        final videoStream = manifest.videoOnly.withHighestBitrate();
        final audioStream = manifest.audioOnly.withHighestBitrate();

        final tempVideoPath = '${tempDir.path}/temp_video.mp4';
        final tempAudioPath = '${tempDir.path}/temp_audio.m4a';
        final tempVideoFile = File(tempVideoPath);
        final tempAudioFile = File(tempAudioPath);

        if (tempVideoFile.existsSync()) await tempVideoFile.delete();
        if (tempAudioFile.existsSync()) await tempAudioFile.delete();

        // Download video
        final videoDownloadStream = yt.videos.streamsClient.get(videoStream);
        final videoFileStream = tempVideoFile.openWrite();
        int videoDownloadedBytes = 0;
        final videoTotalBytes = videoStream.size.totalBytes;

        await for (final chunk in videoDownloadStream) {
          videoDownloadedBytes += chunk.length;
          videoFileStream.add(chunk);
          if (videoTotalBytes > 0) {
            onProgress((videoDownloadedBytes / videoTotalBytes) * 0.5);
          }
        }
        await videoFileStream.flush();
        await videoFileStream.close();

        // Download audio
        final audioDownloadStream = yt.videos.streamsClient.get(audioStream);
        final audioFileStream = tempAudioFile.openWrite();
        int audioDownloadedBytes = 0;
        final audioTotalBytes = audioStream.size.totalBytes;

        await for (final chunk in audioDownloadStream) {
          audioDownloadedBytes += chunk.length;
          audioFileStream.add(chunk);
          if (audioTotalBytes > 0) {
            onProgress(0.5 + (audioDownloadedBytes / audioTotalBytes) * 0.5);
          }
        }
        await audioFileStream.flush();
        await audioFileStream.close();

        // Gabungkan dengan FFmpeg
        final session = await FFmpegKit.execute(
          '-i "$tempVideoPath" -i "$tempAudioPath" -c:v copy -c:a aac -y "$filePath"',
        );
        final returnCode = await session.getReturnCode();
        if (returnCode?.isValueSuccess() != true) {
          throw Exception('Gagal menggabungkan video dan audio');
        }

        await tempVideoFile.delete();
        await tempAudioFile.delete();
        debugPrint("✅ Berhasil diunduh dan digabungkan ke: $filePath");
      }

      // 5) Simpan ke Galeri
      final bool? saved = await GallerySaver.saveVideo(filePath);
      if (saved == true) {
        debugPrint("📂 Berhasil disimpan ke Galeri");
        onComplete(filePath);
      } else {
        throw Exception('Gagal menyimpan ke Galeri');
      }
    } catch (e) {
      debugPrint("❌ Terjadi error: $e");
      onError(e.toString());
    } finally {
      yt.close();
    }
  }
}
