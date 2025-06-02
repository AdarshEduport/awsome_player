import 'dart:developer';

import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:awesome_video_player_example/constants.dart';
import 'package:flutter/material.dart';

class HlsTracksPage extends StatefulWidget {
  @override
  _HlsTracksPageState createState() => _HlsTracksPageState();
}

class _HlsTracksPageState extends State<HlsTracksPage> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    final hi ='https://repo.jellyfin.org/archive/jellyfish/media/jellyfish-400-mbps-4k-uhd-hevc-10bit.mkv';
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
    );
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      bufferingConfiguration: BetterPlayerBufferingConfiguration(
        cleanInit:true ,
        // useSWOnly: true
      ),
      
      Constants.hlsTestStreamUrl,
      useAsmsSubtitles: true,
      videoFormat: BetterPlayerVideoFormat.hls
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
    _betterPlayerController.addEventsListener((e){
      if(e.betterPlayerEventType==BetterPlayerEventType.analytics){
 log('EVENT----${e.betterPlayerEventType}==${e.parameters}');
      }
     
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("HLS tracks"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Player with HLS stream which loads tracks from HLS."
              " You can choose tracks by using overflow menu (3 dots in right corner).",
              style: TextStyle(fontSize: 16),
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),
        ],
      ),
    );
  }
}
