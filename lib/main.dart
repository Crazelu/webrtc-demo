import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Webrtc Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Webrtc Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final sdpController = TextEditingController();

  late RTCPeerConnection _peerConnection;
  late MediaStream localStream;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  bool isOffer = false;

  @override
  void initState() {
    super.initState();

    initialize();
    getUserMedia();
  }

  @override
  void dispose() {
    sdpController.dispose();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    final configuration = <String, dynamic>{
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302'
          ]
        }
      ]
    };

    final offerSdpConstraints = <String, dynamic>{
      "mandatory": {
        "OfferToRecieveAudio": true,
        "OfferToRecieveVideo": true,
      },
      "optional": [],
    };

    await getUserMedia();

    //create peer connection
    RTCPeerConnection peerConnection = await createPeerConnection(
      configuration,
      offerSdpConstraints,
    );

    //add local stream
    peerConnection.addStream(localStream);

    //when an ice candidate is sent, print encoded json
    peerConnection.onIceCandidate = (ice) {
      if (ice.candidate != null) {
        print(
          json.encode(
            {
              'candidate': ice.candidate.toString(),
              'sdpMid': ice.sdpMid.toString(),
              'sdpMlineIndex': ice.sdpMlineIndex.toString(),
            },
          ),
        );
      }
    };

    //log connection state whenever it changes
    peerConnection.onIceConnectionState = print;

    //add stream to remote renderer
    peerConnection.onAddStream = (stream) {
      remoteRenderer.srcObject = stream;
    };

    _peerConnection = peerConnection;
  }

  ///Creates an offer sdp
  Future<void> createOffer() async {
    RTCSessionDescription sessionDescription =
        await _peerConnection.createOffer(
      {
        'offerToRecieveVideo': 1,
        'offerToRecieveAudio': 1,
      },
    );

    var session = parse(sessionDescription.sdp ?? '');

    print(
      json.encode(session),
    );

    isOffer = true;

    await _peerConnection.setLocalDescription(sessionDescription);
  }

  ///Initialize local and remote renderers
  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  ///Requests permission to use user media
  ///and adds stream to local renderer
  Future<void> getUserMedia() async {
    final stream = await navigator.mediaDevices.getUserMedia(
      {
        "audio": false,
        "video": {"facingMode": "user"},
      },
    );
    localRenderer.srcObject = stream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            videoRenderers(),
            offerAndAnswerButtons(),
            sdpCandidateTF(),
            sdpCandidateButtons(),
          ],
        ),
      ),
    );
  }

  Row sdpCandidateButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () {},
            child: Text("Set remote description"),
          ),
          ElevatedButton(
            onPressed: () {},
            child: Text("Set candidate"),
          ),
        ],
      );

  Padding sdpCandidateTF() => Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: sdpController,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          maxLength: TextField.noMaxLength,
        ),
      );

  Row offerAndAnswerButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () {},
            child: Text("Create Offer"),
          ),
          ElevatedButton(
            onPressed: () {},
            child: Text("Create Answer"),
          ),
        ],
      );

  SizedBox videoRenderers() => SizedBox(
        height: 310,
        child: Row(
          children: [
            Flexible(
              child: Container(
                key: Key('local'),
                margin: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black,
                ),
                child: RTCVideoView(
                  localRenderer,
                  mirror: true,
                ),
              ),
            ),
            Flexible(
              child: Container(
                key: Key('remote'),
                margin: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black,
                ),
                child: RTCVideoView(remoteRenderer),
              ),
            ),
          ],
        ),
      );
}
