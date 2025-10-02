import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:permission_handler/permission_handler.dart';

class YoutubeDownloader {
  final yt = YoutubeExplode();

  /// Minta izin sesuai versi Android
  Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      // Cek versi Android
      final sdkInt = int.tryParse(
        (await Process.run('getprop', [
          'ro.build.version.sdk',
        ])).stdout.toString().trim(),
      );

      if (sdkInt != null && sdkInt >= 33) {
        // ✅ Android 13 ke atas (API 33+)
        var videoStatus = await Permission.videos.request();
        var imageStatus = await Permission.photos.request();
        var audioStatus = await Permission.audio.request();

        if (videoStatus.isDenied &&
            imageStatus.isDenied &&
            audioStatus.isDenied) {
          throw Exception("Izin media ditolak.");
        }
      } else {
        // ✅ Android 12 ke bawah
        var status = await Permission.storage.request();
        if (status.isDenied) {
          throw Exception("Izin penyimpanan ditolak.");
        }
      }
    }
  }

  /// Download video YouTube
  Future<void> downloadVideo(
    String url, {
    required void Function(double progress) onProgress,
  }) async {
    try {
      // Pastikan izin diberikan
      await requestPermission();

      // Ambil informasi video
      var video = await yt.videos.get(url);
      debugPrint("🎬 Judul Video: ${video.title}");

      // Ambil manifest stream
      var manifest = await yt.videos.streamsClient.getManifest(video.id);

      StreamInfo? streamInfo;
      if (manifest.muxed.isNotEmpty) {
        streamInfo = manifest.muxed.withHighestBitrate();
      } else if (manifest.video.isNotEmpty) {
        streamInfo = manifest.video.withHighestBitrate();
      } else if (manifest.audio.isNotEmpty) {
        streamInfo = manifest.audio.withHighestBitrate();
      }

      if (streamInfo == null) {
        throw Exception('Tidak ada stream video yang cocok.');
      }

      // Simpan ke folder Download
      final dir = Directory("/storage/emulated/0/Download");
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Pastikan nama file aman
      final safeTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), "_");
      final filePath = "${dir.path}/$safeTitle.mp4";

      var dio = Dio();
      await dio.download(
        streamInfo.url.toString(),
        filePath,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            onProgress(count / total);
          }
        },
      );

      debugPrint("✅ Video tersimpan di: $filePath");
    } catch (e) {
      debugPrint("❌ Error: $e");
    } finally {
      yt.close();
    }
  }
}
