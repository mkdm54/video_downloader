import 'package:flutter/material.dart';
import 'package:video_downloader/components/custom_button.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: platforms.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
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
        debugPrint("Download YouTube dari URL: $url");
        break;
      case "TikTok":
        debugPrint("Download TikTok dari URL: $url");
        break;
      case "Instagram":
        debugPrint("Download Instagram dari URL: $url");
        break;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Sedang download dari $currentTab...")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Video Downloader"),
        bottom: TabBar(
          controller: _tabController,
          tabs: platforms.map((platform) => Tab(text: platform)).toList(),
        ),
      ),
      body: UrlVideo(urlController: _urlController, onDownload: _download),
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
              prefixIcon: const Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 20),
          CustomButton(onPressed: onDownload, title: "Download"),
        ],
      ),
    );
  }
}
