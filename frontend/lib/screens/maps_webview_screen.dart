import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MapsWebviewScreen extends StatefulWidget {
  final String foodName;
  final double latitude;
  final double longitude;

  const MapsWebviewScreen({
    super.key,
    required this.foodName,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<MapsWebviewScreen> createState() => _MapsWebviewScreenState();
}

class _MapsWebviewScreenState extends State<MapsWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final query = Uri.encodeComponent(widget.foodName);
    final url = 'https://www.google.com/maps/search/$query/@${widget.latitude},${widget.longitude},15z';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;

            // intent://, market://, tel://, mailto:// 등 특수 스킴 처리
            if (url.startsWith('intent://') ||
                url.startsWith('market://') ||
                url.startsWith('tel:') ||
                url.startsWith('mailto:') ||
                url.startsWith('geo:') ||
                url.startsWith('google.navigation:')) {
              try {
                // intent:// 스킴을 https로 변환 시도
                if (url.startsWith('intent://')) {
                  // intent URL에서 fallback URL 추출
                  final fallbackMatch = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(url);
                  if (fallbackMatch != null) {
                    final fallbackUrl = Uri.decodeComponent(fallbackMatch.group(1)!);
                    final uri = Uri.parse(fallbackUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  } else {
                    // Google Maps 앱으로 열기 시도
                    final query = Uri.encodeComponent(widget.foodName);
                    final mapsUrl = Uri.parse('https://www.google.com/maps/search/$query/@${widget.latitude},${widget.longitude},15z');
                    if (await canLaunchUrl(mapsUrl)) {
                      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
                    }
                  }
                } else {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              } catch (e) {
                print('URL 열기 실패: $e');
              }
              return NavigationDecision.prevent;
            }

            // 일반 http/https URL은 WebView에서 계속 로드
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _loadingProgress = 0;
            });
          },
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            // ERR_UNKNOWN_URL_SCHEME 오류 무시
            if (error.description?.contains('ERR_UNKNOWN_URL_SCHEME') == true) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('페이지 로드 오류: ${error.description}'),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.foodName}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              '주변 음식점 검색',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.reload(),
            tooltip: '새로고침',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 로딩 프로그레스 바
          if (_isLoading)
            LinearProgressIndicator(
              value: _loadingProgress,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 3,
            ),

          // WebView
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading && _loadingProgress < 0.3)
                  Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.map_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '지도를 불러오는 중...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.foodName} 검색 중',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
