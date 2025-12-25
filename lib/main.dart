import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بڕاوسەری یەکگرتوو',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NotoNaskhArabic',
        useMaterial3: true,
      ),
      home: const BrowserHome(),
    );
  }
}

class BrowserHome extends StatefulWidget {
  const BrowserHome({super.key});

  @override
  _BrowserHomeState createState() => _BrowserHomeState();
}

class _BrowserHomeState extends State<BrowserHome> {
  late final WebViewController _webViewController;
  
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  double _progress = 0.0;
  String _currentUrl = 'https://www.google.com';
  String _currentViewMode = 'Desktop'; // گۆڕدرا بۆ Desktop وەک default
  
  List<String> _bookmarks = [];
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _urlController.text = _currentUrl;
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // Desktop User Agent بەکار دەهێنین بۆ OAuth
      ..setUserAgent(UserAgents.desktop)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
              _urlController.text = url;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _addToHistory(url);
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Web Resource Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // ئەگەر لینکی Google OAuth بوو، لە بڕاوسەری دەرەکی بیکەوە
            if (request.url.contains('accounts.google.com') && 
                request.url.contains('oauth')) {
              _openInExternalBrowser(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  // کردنەوەی لینک لە بڕاوسەری دەرەکی
  Future<void> _openInExternalBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // بە بڕاوسەری سیستەم بیکەوە
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لۆگین لە بڕاوسەری دەرەکی کرایەوە'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookmarks = prefs.getStringList('bookmarks') ?? [];
      _history = prefs.getStringList('history') ?? [];
    });
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarks', _bookmarks);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', _history);
  }

  Future<void> _addToHistory(String url) async {
    if (_history.isEmpty || _history.last != url) {
      _history.add(url);
      if (_history.length > 50) _history.removeAt(0);
      await _saveHistory();
    }
  }

  Future<void> _setupGameCenter() async {
    const gameCenterUrl = 'https://gamecenter.apple.com';
    if (await canLaunchUrl(Uri.parse(gameCenterUrl))) {
      await launchUrl(Uri.parse(gameCenterUrl));
    } else {
      _loadUrl(gameCenterUrl);
    }
  }

  void _loadUrl(String url) {
    String finalUrl = url.trim();
    if (finalUrl.isEmpty) return;
    
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      if (finalUrl.contains('.') && !finalUrl.contains(' ')) {
        finalUrl = 'https://$finalUrl';
      } else {
        finalUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(finalUrl)}';
      }
    }
    
    _webViewController.loadRequest(Uri.parse(finalUrl));
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _addBookmark() {
    if (!_bookmarks.contains(_currentUrl)) {
      setState(() {
        _bookmarks.add(_currentUrl);
      });
      _saveBookmarks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وێبسایت زیاد کرا بۆ نیشانەکان')),
      );
    }
  }

  // گۆڕینی جۆری دیمەن
  Future<void> _switchViewMode(String mode) async {
    String newUserAgent;

    switch (mode) {
      case 'iPad':
        newUserAgent = UserAgents.ipad;
        break;
      case 'Desktop':
        newUserAgent = UserAgents.desktop;
        break;
      case 'iPhone':
      default:
        newUserAgent = UserAgents.iphone;
        break;
    }

    await _webViewController.setUserAgent(newUserAgent);
    await _webViewController.reload();
    
    setState(() {
      _currentViewMode = mode;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جۆری دیمەن گۆڕدرا بۆ $mode')),
      );
    }
  }

  // کردنەوەی لاپەڕەی ئێستا لە بڕاوسەری دەرەکی
  Future<void> _openCurrentInExternalBrowser() async {
    await _openInExternalBrowser(_currentUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بڕاوسەری یەکگرتوو'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.gamepad),
            onPressed: _setupGameCenter,
            tooltip: 'گەیم سێنتەر',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'bookmarks',
                child: Row(children: [
                  Icon(Icons.bookmark, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('نیشانەکان')
                ]),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(children: [
                  Icon(Icons.history, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('مێژوو')
                ]),
              ),
              const PopupMenuDivider(),
              // جۆری دیمەن
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'جۆری دیمەن',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'viewmode_iphone',
                child: Row(children: [
                  Icon(
                    Icons.phone_iphone,
                    color: _currentViewMode == 'iPhone' ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text('iPhone'),
                  if (_currentViewMode == 'iPhone')
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.check, color: Colors.blue, size: 18),
                    ),
                ]),
              ),
              PopupMenuItem(
                value: 'viewmode_ipad',
                child: Row(children: [
                  Icon(
                    Icons.tablet_mac,
                    color: _currentViewMode == 'iPad' ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text('iPad'),
                  if (_currentViewMode == 'iPad')
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.check, color: Colors.blue, size: 18),
                    ),
                ]),
              ),
              PopupMenuItem(
                value: 'viewmode_desktop',
                child: Row(children: [
                  Icon(
                    Icons.computer,
                    color: _currentViewMode == 'Desktop' ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text('Desktop'),
                  if (_currentViewMode == 'Desktop')
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.check, color: Colors.blue, size: 18),
                    ),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'open_external',
                child: Row(children: [
                  Icon(Icons.open_in_browser, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('کردنەوە لە بڕاوسەری دەرەکی')
                ]),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 8),
                  Text('نوێکردنەوە')
                ]),
              ),
            ],
            onSelected: (value) {
              if (value == 'bookmarks') {
                _showBookmarks();
              } else if (value == 'history') {
                _showHistory();
              } else if (value == 'refresh') {
                _webViewController.reload();
              } else if (value == 'viewmode_iphone') {
                _switchViewMode('iPhone');
              } else if (value == 'viewmode_ipad') {
                _switchViewMode('iPad');
              } else if (value == 'viewmode_desktop') {
                _switchViewMode('Desktop');
              } else if (value == 'open_external') {
                _openCurrentInExternalBrowser();
              }
            },
          ),
        ],
      ),
      
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(value: _progress, minHeight: 3),
            
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () => _loadUrl('https://www.google.com'),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: () async {
                    if (await _webViewController.canGoBack()) {
                      _webViewController.goBack();
                    }
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    textInputAction: TextInputAction.go,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                      hintText: 'گەڕان یان ناونیشان...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _isLoading 
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _urlController.clear(),
                          ),
                    ),
                    onSubmitted: (value) => _loadUrl(value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  onPressed: () async {
                    if (await _webViewController.canGoForward()) {
                      _webViewController.goForward();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: _addBookmark,
                ),
              ],
            ),
          ),
          
          Expanded(
            child: WebViewWidget(controller: _webViewController),
          ),
        ],
      ),
    );
  }

  void _showBookmarks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نیشانەکان'),
        content: SizedBox(
          width: double.maxFinite,
          child: _bookmarks.isEmpty
              ? const Text('هیچ نیشانەیەک نیە')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.bookmark),
                    title: Text(
                      _bookmarks[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _bookmarks.removeAt(index);
                          _saveBookmarks();
                        });
                        Navigator.pop(context);
                        _showBookmarks();
                      },
                    ),
                    onTap: () {
                      _loadUrl(_bookmarks[index]);
                      Navigator.pop(context);
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('داخستن'),
          ),
        ],
      ),
    );
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مێژووی سەردان'),
        content: SizedBox(
          width: double.maxFinite,
          child: _history.isEmpty
              ? const Text('هیچ مێژویەک نیە')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _history.reversed.toList().length,
                  itemBuilder: (context, index) {
                    final reversedList = _history.reversed.toList();
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(
                        reversedList[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        _loadUrl(reversedList[index]);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _history.clear();
                _saveHistory();
              });
              Navigator.pop(context);
            },
            child: const Text(
              'سڕینەوەی هەموو',
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('داخستن'),
          ),
        ],
      ),
    );
  }
}

class UserAgents {
  static const String iphone = 
      "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1";

  static const String ipad = 
      "Mozilla/5.0 (iPad; CPU OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1";

  // Desktop User Agent بۆ OAuth
  static const String desktop = 
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
}