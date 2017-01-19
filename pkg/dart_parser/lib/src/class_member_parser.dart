// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_parser.class_member_parser;

import 'package:dart_scanner/src/token.dart' show
    Token;

import 'listener.dart' show
    Listener;

import 'parser.dart' show
    Parser;

/// Parser similar to [TopLevelParser] but also parses class members (excluding
/// their bodies).
class ClassMemberParser extends Parser {
  ClassMemberParser(Listener listener,
      {bool asyncAwaitKeywordsEnabled: false,
       bool enableGenericMethodSyntax: false})
      : super(listener, asyncAwaitKeywordsEnabled: asyncAwaitKeywordsEnabled,
          enableGenericMethodSyntax: enableGenericMethodSyntax);

  Token parseExpression(Token token) => skipExpression(token);

  // This method is overridden for two reasons:
  // 1. Avoid generating events for arguments.
  // 2. Avoid calling skip expression for each argument (which doesn't work).
  Token parseArgumentsOpt(Token token) => skipArgumentsOpt(token);

  Token parseFunctionBody(Token token, bool isExpression, bool allowAbstract) {
    return skipFunctionBody(token, isExpression, allowAbstract);
  }
}
