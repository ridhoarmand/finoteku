import 'dart:convert';

import 'package:finoteku/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('fetchAllRows pages past the 1000-row server cap', () async {
    const total = 2500;
    final offsets = <String>[];
    final client = SupabaseClient(
      'http://localhost',
      'anon',
      httpClient: MockClient((req) async {
        final offset = int.parse(req.url.queryParameters['offset'] ?? '0');
        final limit = int.parse(req.url.queryParameters['limit']!);
        offsets.add('$offset');
        expect(
          req.url.queryParameters['order'],
          'date.desc.nullslast,id.asc.nullslast',
        );
        final end = (offset + limit).clamp(0, total);
        final rows = [
          for (var i = offset; i < end; i++) {'id': i},
        ];
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: req,
        );
      }),
    );

    final rows = await fetchAllRows(
      client
          .from('transactions')
          .select()
          .order('date')
          .order('id', ascending: true),
    );

    expect(rows.length, total);
    expect(rows.map((r) => r['id']).toSet().length, total);
    expect(offsets, ['0', '1000', '2000']);
  });
}
