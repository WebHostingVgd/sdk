// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.type_builder;

import 'builder.dart' show
    Builder,
    TypeVariableBuilder;

import 'scope.dart' show
    Scope;

// TODO(ahe): Make const class.
abstract class TypeBuilder extends Builder {
  void resolveIn(Scope scope);

  String get debugName;

  StringBuffer printOn(StringBuffer buffer);

  String toString() => "$debugName(${printOn(new StringBuffer())})";

  TypeBuilder subst(Map<TypeVariableBuilder, TypeBuilder> substitution) => this;
}
