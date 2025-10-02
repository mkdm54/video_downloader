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
    // Izin tidak diperlukan untuk platform selain Android.
    if (!Platform.isAndroid) return;

    // Untuk Android 13+, kita butuh izin individual untuk media.
    // Jika salah satu diberikan, itu sudah cukup.
    if (await Permission.videos.request().isGranted) return;
    if (await Permission.photos.request().isGranted) return;

    // Fallback untuk Android versi lebih lama.
    if (await Permission.storage.request().isGranted) return;

    // Jika semua permintaan ditolak, lempar error.
    throw Exception('Izin untuk menyimpan media ke galeri ditolak.');
  }

  /// Mengunduh video dari URL YouTube dan menyimpannya ke galeri.
  ///
  /// [url]: URL video YouTube yang valid.
  /// [onProgress]: Callback untuk melaporkan progres download (nilai antara 0.0 dan 1.0).
  /// [onError]: Callback yang dipanggil jika terjadi kesalahan.
  /// [onComplete]: Callback yang dipanggil setelah video berhasil diunduh dan disimpan.
  Future<void> downloadVideo({
    required String url,
    required void Function(double progress) onProgress,
    required void Function(String message) onError,
    required void Function(String filePath) onComplete,
  }) async {
    try {
      // Langkah 1: Meminta izin penyimpanan/media sebelum memulai.
      await requestPermission();

      // Langkah 2: Mengambil metadata video dari YouTube.
      final video = await yt.videos.get(url);
      debugPrint("🎬 Judul Video: ${video.title}");

      // Langkah 3: Mengambil manifest stream dan memilih kualitas terbaik.
      final manifest = await yt.videos.streamsClient.getManifest(video.id);

      // Langkah 4: Menyiapkan path file sementara di direktori internal aplikasi.
      final tempDir = await getTemporaryDirectory();
      final safeTitle = video.title
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), "_")
          .trim();
      final filePath = '${tempDir.path}/$safeTitle.mp4';
      final file = File(filePath);

      // Hapus file lama jika ada untuk menghindari konflik.
      if (file.existsSync()) {
        await file.delete();
      }

      if (manifest.muxed.isNotEmpty) {
        // Jika ada stream muxed (video+audio), gunakan itu.
        final streamInfo = manifest.muxed.withHighestBitrate();

        // Langkah 5: Memulai proses streaming dan download.
        final stream = yt.videos.streamsClient.get(streamInfo);
        final fileStream = file.openWrite();
        final totalBytes = streamInfo.size.totalBytes;
        int downloadedBytes = 0;

        await for (final chunk in stream) {
          downloadedBytes += chunk.length;
          fileStream.add(chunk);

          // Melaporkan progres ke UI
          if (totalBytes > 0) {
            onProgress(downloadedBytes / totalBytes);
          }
        }

        await fileStream.flush();
        await fileStream.close();

        debugPrint(
          "✅ Berhasil diunduh (muxed) ke direktori sementara: $filePath",
        );
      } else {
        // Jika tidak ada muxed, download video dan audio terpisah, lalu gabungkan.
        final videoStream = manifest.videoOnly.withHighestBitrate();
        final audioStream = manifest.audioOnly.withHighestBitrate();

        // Path untuk file sementara video dan audio
        final tempVideoPath = '${tempDir.path}/temp_video.mp4';
        final tempAudioPath = '${tempDir.path}/temp_audio.m4a';
        final tempVideoFile = File(tempVideoPath);
        final tempAudioFile = File(tempAudioPath);

        // Hapus file temp lama jika ada
        if (tempVideoFile.existsSync()) await tempVideoFile.delete();
        if (tempAudioFile.existsSync()) await tempAudioFile.delete();

        // Download video
        final videoDownloadStream = yt.videos.streamsClient.get(videoStream);
        final videoFileStream = tempVideoFile.openWrite();
        final videoTotalBytes = videoStream.size.totalBytes;
        int videoDownloadedBytes = 0;

        await for (final chunk in videoDownloadStream) {
          videoDownloadedBytes += chunk.length;
          videoFileStream.add(chunk);
          if (videoTotalBytes > 0) {
            onProgress((videoDownloadedBytes / videoTotalBytes) * 0.5); // 0-50%
          }
        }
        await videoFileStream.flush();
        await videoFileStream.close();

        // Download audio
        final audioDownloadStream = yt.videos.streamsClient.get(audioStream);
        final audioFileStream = tempAudioFile.openWrite();
        final audioTotalBytes = audioStream.size.totalBytes;
        int audioDownloadedBytes = 0;

        await for (final chunk in audioDownloadStream) {
          audioDownloadedBytes += chunk.length;
          audioFileStream.add(chunk);
          if (audioTotalBytes > 0) {
            onProgress(
              0.5 + (audioDownloadedBytes / audioTotalBytes) * 0.5,
            ); // 50-100%
          }
        }
        await audioFileStream.flush();
        await audioFileStream.close();

        // Gabungkan video dan audio menggunakan FFmpeg
        final session = await FFmpegKit.execute(
          '-i $tempVideoPath -i $tempAudioPath -c copy -y $filePath',
        );
        final returnCode = await session.getReturnCode();

        if (returnCode?.isValueSuccess() != true) {
          throw Exception(
            'Gagal menggabungkan video dan audio: ${await session.getOutput()}',
          );
        }

        // Hapus file temp
        await tempVideoFile.delete();
        await tempAudioFile.delete();

        debugPrint(
          "✅ Berhasil diunduh dan digabungkan ke direktori sementara: $filePath",
        );
      }

      // Langkah 6: Menyimpan file video dari path sementara ke galeri publik.
      final bool? saved = await GallerySaver.saveVideo(filePath);
      if (saved == true) {
        debugPrint("📂 Berhasil disimpan ke Galeri");
        onComplete(filePath);
      } else {
        throw Exception(
          "Gagal menyimpan ke Galeri (GallerySaver mengembalikan false).",
        );
      }
    } catch (e) {
      debugPrint("❌ Terjadi error saat download/simpan: $e");
      onError(e.toString());
    } finally {
      // Selalu tutup koneksi YoutubeExplode untuk membersihkan resources.
      yt.close();
    }
  }
}
