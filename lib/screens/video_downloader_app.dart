import 'package:flutter/material.dart';
import 'package:video_downloader/components/custom_button.dart';
import 'package:video_downloader/tools/youtube_downloader.dart';

class VideoDownloaderApp extends StatefulWidget {
  const VideoDownloaderApp({super.key});

  @override
  State<VideoDownloaderApp> createState() => _VideoDownloaderAppState();
}

class _VideoDownloaderAppState extends State<VideoDownloaderApp>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  final List<String> platforms = ["YouTube", "TikTok", "Instagram"];

  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: platforms.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _download() {
    final url = _urlController.text;
    final currentTab = platforms[_tabController.index];

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Masukkan URL terlebih dahulu")),
      );
      return;
    }

    switch (currentTab) {
      case "YouTube":
        final downloader = YoutubeDownloader();
        downloader.downloadVideo(
          url: url,
          onProgress: (progress) {
            setState(() {
              _progress = progress;
            });
          },
          onError: (message) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
          onComplete: (filePath) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Download completed!")),
            );
            setState(() {
              _progress = 0;
            });
          },
        );
        break;

      case "TikTok":
        debugPrint("Download TikTok dari URL: $url");
        break;
      case "Instagram":
        debugPrint("Download Instagram dari URL: $url");
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("Video Downloader"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color(0xFF6200EE),
          unselectedLabelColor: Colors.grey,
          tabs: platforms.map((platform) => Tab(text: platform)).toList(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: UrlVideo(
              urlController: _urlController,
              onDownload: _download,
            ),
          ),
          if (_progress > 0 && _progress < 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: LinearProgressIndicator(value: _progress),
            ),
        ],
      ),
    );
  }
}

class UrlVideo extends StatelessWidget {
  final TextEditingController urlController;
  final VoidCallback onDownload;

  const UrlVideo({
    super.key,
    required this.urlController,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: urlController,
            decoration: InputDecoration(
              hintText: "Masukkan link video...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.link, color: Color(0xFF6200EE)),
            ),
          ),
          const SizedBox(height: 20),
          CustomButton(onPressed: onDownload, title: "Download"),
        ],
      ),
    );
  }
}
