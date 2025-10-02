import 'dart:io';
import 'package:flutter/foundation.dart';
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
      // Prioritas: Muxed (video+audio) > Video-only.
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final streamInfo = manifest.muxed.isNotEmpty
          ? manifest.muxed.withHighestBitrate()
          : manifest.videoOnly.withHighestBitrate();

      // Langkah 4: Menyiapkan path file sementara di direktori internal aplikasi.
      // Ini adalah lokasi yang aman untuk menulis file sebelum memindahkannya ke galeri.
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

      debugPrint("✅ Berhasil diunduh ke direktori sementara: $filePath");

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
