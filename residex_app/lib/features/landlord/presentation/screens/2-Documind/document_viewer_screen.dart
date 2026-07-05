import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/datasources/document_file_cache.dart';
import '../../../data/datasources/documind_remote_datasource.dart';
import '../../providers/documind_provider.dart';

/// Opens a cited source PDF, jumped to the page it was cited from.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String docId;
  final String filename;
  final int? page;

  const DocumentViewerScreen({
    super.key,
    required this.propertyId,
    required this.docId,
    required this.filename,
    this.page,
  });

  @override
  ConsumerState<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  final _cache = DocumentFileCache();
  final _controller = PdfViewerController();
  late final Future<File> _fileFuture;

  @override
  void initState() {
    super.initState();
    final getViewUrl = ref.read(documindGetViewUrlActionProvider);
    _fileFuture = _cache.getOrDownload(
      docId: widget.docId,
      fetchViewUrl: () => getViewUrl(propertyId: widget.propertyId, docId: widget.docId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(widget.filename, style: AppTextStyles.titleMedium, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.paper,
      ),
      body: FutureBuilder<File>(
        future: _fileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.registry));
          }

          if (snapshot.hasError) {
            final isNotFound = snapshot.error is DocumentNotFoundException;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  isNotFound
                      ? 'This document is no longer available.'
                      : 'Could not load this document.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return SfPdfViewer.file(
            snapshot.data!,
            controller: _controller,
            onDocumentLoaded: (_) {
              if (widget.page != null && widget.page! > 0) {
                _controller.jumpToPage(widget.page!);
              }
            },
          );
        },
      ),
    );
  }
}
