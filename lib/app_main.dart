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
  // State
  bool _isConnected = false;
  String _dbIp = "{init}";
  String _accessToken = "{init}";
  String _selectedMode = "wallpad";

  // for mode select
  final _modeList = ['wallpad', 'lobby'];

  // for get AccessToken
  final _tokenUrl = "http://52.79.153.213:18584/oauth/token";

  // validate Keys
  final Map<String, GlobalKey<FormState>> _validationKeyMap = {
    "ipValidateKey": GlobalKey<FormState>(),
    "wallpadConnectionValidationKey": GlobalKey<FormState>()
  };

  final Map<String, GlobalKey> _buttonKeyMap = {};

  // TextField Controllers
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _siteController = TextEditingController();
  final TextEditingController _dongController = TextEditingController();
  final TextEditingController _hoController = TextEditingController();
  final TextEditingController _lobbyNumController = TextEditingController();

  final TextEditingController _responseDataController = TextEditingController();

  final TextEditingController _consoleController = TextEditingController();
  final ScrollController _consoleScrollController = ScrollController();

  // websocket channel
  late WebSocketChannel _channel;

  @override
  void initState() {
    super.initState();
    _initWidgets();
    _consoleController.text = "[init] ${widget.title} launch";

  }

  Future<bool> _getAccessToken() async {
    if (_accessToken != "{init}") {
      _appendConsole("[getAccessToken] use cached accessToken: $_accessToken");
      return true;
    }

    _appendConsole("[getAccessToken] POST http://52.79.153.213:18584/oauth/token");
    Response response = await Dio().post(
      _tokenUrl,
      data: {"username": "server_team_test","password": "1q2w3e4r!"},
      options: Options(
        headers: {
          Headers.contentTypeHeader: Headers.jsonContentType
        }
      ),
    );
    _appendConsole("[response getAccessToken] status=${response.statusCode}");

    if (response.statusCode == 200) {
      Map responseBody = Map.from(response.data);
      _accessToken = responseBody["access_token"] as String;
      return true;
    }
    return false;
  }

  Future<bool> _getDbIp() async {
    if (_selectedMode == 'wallpad') {
      return _getWallpadIp();
    } else if (_selectedMode == 'lobby') {
      return _getLobbyIp();
    }
    _appendConsole("mode select fail");
    return false;
  }

  Future<bool> _getWallpadIp() async {
    if (_ipController.text.isEmpty || _siteController.text.isEmpty || _dongController.text.isEmpty || _hoController.text.isEmpty) {
      _showSimpleDialog("alert", "need Household Info [ip, siteId, dong, ho]");
      return false;
    }

    await _getAccessToken();
    final donghoWallpadUrl = "http://192.168.2.89:41234/dongho/wallpad?siteId=${_siteController.text}&dong=${_dongController.text}&ho=${_hoController.text}&access_token=$_accessToken&targetIp=${_ipController.text}&targetPort=30001";
    _appendConsole("[_getWallpadIp] GET $donghoWallpadUrl");
    Response response;
    try {
      response = await Dio().get(donghoWallpadUrl);
    } catch (e) {
      _appendConsole("fail to get DBIP");
      return false;
    }
    _appendConsole("[response getDonghoWallpad] status=${response.statusCode}");

    if (response.statusCode == 200) {
      Map responseBody = Map.from(response.data);
      List<dynamic> wallpadList = responseBody["wallpadList"];
      Map<String, dynamic> wallpadInfo = wallpadList[0];
      String ipAddress = wallpadInfo["ipAddress"];
      _dbIp = ipAddress;
      _appendConsole("[response getDonghoWallpad] set DBIP: $ipAddress");
    }
    return true;
  }

  Future<bool> _getLobbyIp() async {
    if (_ipController.text.isEmpty || _siteController.text.isEmpty || _lobbyNumController.text.isEmpty) {
      _showSimpleDialog("alert", "need lobby Info [ip, siteId, lobbyNum]");
      return false;
    }

    await _getAccessToken();
    final getlobbyUrl = "http://192.168.2.89:41234/lobby?siteId=${_siteController.text}&lobbyNo=${_lobbyNumController.text}&access_token=$_accessToken&targetIp=${_ipController.text}&targetPort=30001";
    _appendConsole("[_getLobbyIp] GET $getlobbyUrl");
    Response response;
    try {
      response = await Dio().get(getlobbyUrl);
    } catch (e) {
      _appendConsole("fail to get lobbyIP");
      return false;
    }
    _appendConsole("[response _getLobbyIp] status=${response.statusCode}");

    if (response.statusCode == 200) {
      Map responseBody = Map.from(response.data);
      String ipAddress = responseBody["ipAddress"];
      _dbIp = ipAddress;
      _appendConsole("[response _getLobbyIp] set DBIP: $ipAddress");
    }
    return true;
  }

  void _connectServer() async {
    _appendConsole("Current Mode: $_selectedMode");

    if (!_isValidConnectionInfo()) {
      _showSimpleDialog("not valid", "Please Check Connection Infos");
      return;
    }

    bool isValidToken = await _getAccessToken();
    if (!isValidToken) {
      _showSimpleDialog("not valid", "Fail to get AccessToken");
      return;
    }
    bool isValidDbIp = await _getDbIp();
    if (!isValidDbIp) {
      _showSimpleDialog("not valid", "Fail to get targetIp\nPleas check Dong, ho or lobbyNum");
      return;
    }

    String connectionUrl = _createWebsocketUrl();
    _appendConsole("[connectServer] try connection");

    _channel = WebSocketChannel.connect(Uri.parse(connectionUrl));

    _channel.ready.then((value) => {
      _connectionSuccess()
    });
    
    _channel.stream.listen((message) {
      _handleMessage(message);
    });

    _channel.sink.done.then((value) => {
      _connectionFail()
    });
  }

  void _connectionSuccess() {
    _appendConsole("[connectServer] Connection Ready!");
    _isConnected = true;
    _refreshConnectionButtons();
  }

  void _connectionFail() {
    _appendConsole("[connectServer] Connection Fail(Disconnected)");
    _isConnected = false;
    _refreshConnectionButtons();
  }

  void _disConnectServer() {
    _appendConsole("[disConnectServer] close connect");
    _channel.sink.close(status.normalClosure);

    _isConnected = false;
    _refreshConnectionButtons();
  }

  String _createWebsocketUrl() {
    String targetIp = _ipController.text;
    if (_selectedMode == 'wallpad') {
      String websocketUrl = "ws://192.168.2.89:41234/wallpad/"
          "${_dongController.text}/${_hoController.text}/1?siteId=${_siteController.text}"
          "&version=1&ip=$_dbIp&id=1&access_token=$_accessToken"
          "&targetIp=$targetIp&targetPort=${_portController.text}";
      _appendConsole("[createWebsocketUrl] -> $websocketUrl");
      return websocketUrl;
    } else if (_selectedMode == 'lobby') {
      String websocketUrl = "ws://192.168.2.89:41234/lobby/"
          "${_lobbyNumController.text}?siteId=${_siteController.text}"
          "&version=1&ip=$_dbIp&id=1&access_token=$_accessToken"
          "&targetIp=$targetIp&targetPort=${_portController.text}";
      _appendConsole("[createWebsocketUrl] -> $websocketUrl");
      return websocketUrl;
    }

    return "null";
  }

  bool _isValidConnectionInfo() {
    for (var entry in _validationKeyMap.entries) {
      if (!entry.value.currentState!.validate()) {
        return false;
      }
    }
    return true;
  }

  Future<void> _showSimpleDialog(String title, String message) async {
    return showDialog(
        context: context,
        builder: (builderContext) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'OK'),
                  child: const Text("OK")
              )
            ],
          );
        }
    );
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

  String? _validateLocalhost(String? value) {
    if (value == "127.0.0.1" || value == "localhost") {
      return "no localhost";
    }

    if (value == null || !RegExp("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\$").hasMatch(value)) {
      return "invalid ip format";
    }

    return null;
  }

  String? _validateNotEmpty(String? value) {
    if (value == null || value.isEmpty) {
      return "Not Empty";
    }
    return null;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Form(
                key: _validationKeyMap["wallpadConnectionValidationKey"],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Form(
                      key: _validationKeyMap["ipValidateKey"],
                      child: _preSetInputField(1, "ip", _ipController, _validateLocalhost),
                    ),
                    _preSetInputField(1, "port", _portController, _validateNotEmpty),
                    _preSetInputField(1, "siteId", _siteController, _validateNotEmpty),
                    _preSetInputField(1, "dong", _dongController, _validateNotEmpty),
                    _preSetInputField(1, "ho", _hoController, _validateNotEmpty),
                    _preSetInputField(1, "lobbyNum", _lobbyNumController, _validateNotEmpty),
                  ],
                ),
              ),
              Column(
                children: [
                  TextField(
                    controller: _responseDataController,
                    keyboardType: TextInputType.multiline,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Response Data",
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: DropdownButton(
                              value: _selectedMode,
                              items: _modeList
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedMode = value!;
                                });
                              }),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: _connectButton,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: _disConnectButton,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
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
            ],
          ),
        ),
      ),
    );
  }

  late ElevatedButton _connectButton;
  late ElevatedButton _disConnectButton;

  void _initWidgets() {
    _initTextField();
    _refreshConnectionButtons();
  }

  void _refreshConnectionButtons() {
    setState(() {
      _connectButton = ElevatedButton(
        key: UniqueKey(),
        onPressed: _isConnected ? null : _connectServer,
        child: const Text("Connect Server"),
      );
      _disConnectButton = ElevatedButton(
        key: UniqueKey(),
        onPressed: _isConnected ? _disConnectServer : null,
        child: const Text("Disconnect Server"),
      );
    });
  }

  void _initTextField() {
    _ipController.text = "172.20.200.200";
    _portController.text = "30002";
    _siteController.text = "8";
    _dongController.text = "101";
    _hoController.text = "101";
    _lobbyNumController.text = "1";
    _responseDataController.text = "{\"result\": 200}";
  }

  Flexible _preSetInputField(int flex, String hint, TextEditingController controller,
      Function? validateFunc) {
    if (validateFunc == null) {
      return Flexible(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: hint,
              ),
            ),
          ),
      );
    }

    return Flexible(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: hint,
            ),
            validator: (value) {
              return validateFunc(value);
            },
            autovalidateMode: AutovalidateMode.always,
          ),
        )
    );
  }
}

bool equalsIgnoreCase(String? string1, String? string2) {
  return string1?.toLowerCase() == string2?.toLowerCase();
}