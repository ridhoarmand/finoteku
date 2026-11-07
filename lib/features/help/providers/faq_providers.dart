import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/faq_models.dart';
import '../services/faq_service.dart';

// FAQ service provider
final faqServiceProvider = Provider<FAQService>((ref) {
  return const FAQService();
});

// FAQ data provider
final faqDataProvider = Provider<List<FAQSection>>((ref) {
  final faqService = ref.read(faqServiceProvider);
  return faqService.getAllFAQs();
});
