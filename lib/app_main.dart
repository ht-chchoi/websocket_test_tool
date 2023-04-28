import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class MainPage extends StatelessWidget {
  const MainPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: FlexThemeData.light(scheme: FlexScheme.deepBlue),
      home: MainBody(title: title),
    );
  }
}

class MainBody extends StatefulWidget {
  const MainBody({super.key, required this.title});

  final String title;

  @override
  State<StatefulWidget> createState() => _MainBodyState();
}

class _MainBodyState extends State<MainBody> {
  // for get AccessToken
  final _tokenUrl = "http://52.79.153.213:18584/oauth/token";

  // TextField Controllers
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _siteController = TextEditingController();
  final TextEditingController _dongController = TextEditingController();
  final TextEditingController _hoController = TextEditingController();
  final TextEditingController _dbIpController = TextEditingController();
  final TextEditingController _accessTokenController = TextEditingController();

  final TextEditingController _responseDataController = TextEditingController();

  final TextEditingController _consoleController = TextEditingController();
  final ScrollController _consoleScrollController = ScrollController();

  // websocket channel
  late WebSocketChannel _channel;

  @override
  void initState() {
    super.initState();
    _initTextField();
    _consoleController.text = "[init] ${widget.title} launch";
  }

  void _initTextField() {
    _ipController.text = "172.20.200.200";
    _portController.text = "30002";
    _siteController.text = "8";
    _responseDataController.text = "{\"result\": 200}";
  }

  void _getAccessToken() async {
    _appendConsole("[getAccessToken] POST http://52.79.153.213:18584/oauth/token");
    Response response = await Dio().post(
      _tokenUrl,
      data: {"username": "labs_team","password": "abcd"},
      options: Options(
        headers: {
          Headers.contentTypeHeader: Headers.jsonContentType
        }
      ),
    );
    _appendConsole("[response getAccessToken] status=${response.statusCode}");

    if (response.statusCode == 200) {
      Map responseBody = Map.from(response.data);
      _accessTokenController.text = responseBody["access_token"] as String;
    }
  }

  void _connectServer() {
    String connectionUrl = _createWebsocketUrl();
    _appendConsole("[connectServer] try connection");

    _channel = WebSocketChannel.connect(Uri.parse(connectionUrl));

    _channel.ready.then((value) => {
      _appendConsole("[connectServer] Connection Ready")
    });
    
    _channel.stream.listen((message) {
      // _channel.sink.add('received! $message');
      _handleMessage(message);
    });
  }

  void _disConnectServer() {
    _appendConsole("[disConnectServer] close connect");
    _channel.sink.close(status.normalClosure);
  }

  String _createWebsocketUrl() {
    String targetIp = _ipController.text;
    if (targetIp == "127.0.0.1") {

    }

    String websocketUrl = "ws://192.168.2.89:41234/wallpad/"
        "${_dongController.text}/${_hoController.text}/1?siteId=${_siteController.text}"
        "&version=1&ip=${_dbIpController.text}&id=1&access_token=${_accessTokenController.text}"
        "&targetIp=$targetIp&targetPort=${_portController.text}";
    _appendConsole("[createWebsocketUrl] -> $websocketUrl");
    return websocketUrl;
  }

  void _handleMessage(String message) {
    _appendConsole('[receive] >> $message');

    Map<String, dynamic> requestData = jsonDecode(message);

    if (equalsIgnoreCase(requestData["type"] as String, "notify")) {
      _appendConsole("[response] no response for notify");
      return;
    }

    Map<String, dynamic> responseData = HashMap();
    responseData["id"] = requestData["id"];
    responseData["status"] = 200;
    responseData["data"] = jsonDecode(_responseDataController.text);
    _channel.sink.add(jsonEncode(responseData));
    _appendConsole("[response] ${jsonEncode(responseData)}");
  }

  void _appendConsole(String message) async {
    _consoleController.text = "${_consoleController.text}\n$message";
    await Future.delayed(const Duration(milliseconds: 10));
    _consoleScrollController.jumpTo(_consoleScrollController.position.maxScrollExtent);
  }

  void _clearConsole() {
    _consoleController.text = "clear console ... ";
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _preSetInputField(2, "ip", _ipController),
                    _preSetInputField(1, "port", _portController),
                    _preSetInputField(1, "siteId", _siteController),
                    _preSetInputField(1, "dong", _dongController),
                    _preSetInputField(1, "ho", _hoController),
                    _preSetInputField(2, "dbIp", _dbIpController),
                    _preSetInputField(1, "access_token", _accessTokenController),
                    ElevatedButton(
                      onPressed: _getAccessToken,
                      child: const Text("getToken"),
                    )
                  ],
                )
            ),
            Flexible(
                flex: 8,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 30, bottom: 10),
                      child: TextField(
                        controller: _responseDataController,
                        keyboardType: TextInputType.multiline,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "Response Data",
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: ElevatedButton(
                              onPressed: _connectServer,
                              child: const Text("Connect Server"),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: ElevatedButton(
                              onPressed: _disConnectServer,
                              child: const Text("Disconnect Server"),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
            ),
            Flexible(
                flex: 8,
                child: Column(
                  children: [
                    TextField(
                      controller: _consoleController,
                      scrollController: _consoleScrollController,
                      keyboardType: TextInputType.multiline,
                      maxLines: 15,
                      readOnly: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Console",
                      )
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: ElevatedButton(
                        onPressed: _clearConsole,
                        child: const Text("Clear Console"),
                      ),
                    ),
                  ],
                ),
            ),
          ],
        ),
      ),
    );
  }

  Flexible _preSetInputField(int flex, String hint, TextEditingController controller) {
    return Flexible(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            // height: 120,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: hint,
              ),
            ),
          ),
        )
    );
  }
}

bool equalsIgnoreCase(String? string1, String? string2) {
  return string1?.toLowerCase() == string2?.toLowerCase();
}