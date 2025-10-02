import 'package:flutter/material.dart';

class YoutubeDownloader extends StatelessWidget {
  final String link;
  const YoutubeDownloader({super.key, required this.link});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          // Disini proses download video YouTube pakai link
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Download YouTube: $link")));
        },
        child: const Text("Download YouTube Video"),
      ),
    );
  }
}
