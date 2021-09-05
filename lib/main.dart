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
    connect();
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

    localStream = await getUserMedia();

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
              'sdpMlineIndex': ice.sdpMlineIndex,
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
        'offerToRecieveVideo': true,
        'offerToRecieveAudio': true,
      },
    );

    var session = parse(sessionDescription.sdp ?? '');

    print(
      json.encode(session),
    );

    isOffer = true;

    await _peerConnection.setLocalDescription(sessionDescription);
  }

  Future<void> setRemoteDesc() async {
    String jsonString = sdpController.text;
    final session = await jsonDecode("$jsonString");

    final sdp = write(session, null);
    RTCSessionDescription desc = RTCSessionDescription(
      sdp,
      isOffer ? "answer" : "offer",
    );

    print(desc.toMap());

    await _peerConnection.setRemoteDescription(desc);
  }

  Future<void> createAnswer() async {
    RTCSessionDescription desc = await _peerConnection.createAnswer(
      {
        'offerToRecieveVideo': true,
        'offerToRecieveAudio': true,
      },
    );

    final session = parse(desc.sdp!);

    print(json.encode(session));

    _peerConnection.setLocalDescription(desc);
  }

  ///Initialize local and remote renderers
  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  ///Requests permission to use user media
  ///and adds stream to local renderer
  Future<MediaStream> getUserMedia() async {
    final stream = await navigator.mediaDevices.getUserMedia(
      {
        "audio": true,
        "video": {"facingMode": "user"},
      },
    );
    localRenderer.srcObject = stream;
    return stream;
  }

  Future<void> setCandidate() async {
    String jsonString = sdpController.text;
    final session = await jsonDecode('$jsonString');

    print(session['candidate']);
    final candidate = RTCIceCandidate(
      session['candidate'],
      session['sdpMid'],
      session['sdpMlineIndex'],
    );

    await _peerConnection.addCandidate(candidate);
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
            onPressed: setRemoteDesc,
            child: Text("Set remote description"),
          ),
          ElevatedButton(
            onPressed: setCandidate,
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
            onPressed: createOffer,
            child: Text("Create Offer"),
          ),
          ElevatedButton(
            onPressed: createAnswer,
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
