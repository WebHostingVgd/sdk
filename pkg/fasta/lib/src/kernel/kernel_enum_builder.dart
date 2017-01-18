// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fasta.kernel_enum_builder;

import 'package:kernel/ast.dart' show
    Arguments,
    AsyncMarker,
    Class,
    Constructor,
    ConstructorInvocation,
    DirectPropertyGet,
    Expression,
    Field,
    FieldInitializer,
    IntLiteral,
    InterfaceType,
    ListLiteral,
    MapEntry,
    MapLiteral,
    MethodInvocation,
    Name,
    ProcedureKind,
    ReturnStatement,
    StaticGet,
    StringLiteral,
    ThisExpression,
    VariableGet;

import '../errors.dart' show
    inputError;

import '../modifier.dart' show
    constMask,
    finalMask,
    staticMask;

import "../source/source_class_builder.dart" show
    SourceClassBuilder;

import 'kernel_builder.dart' show
    Builder,
    EnumBuilder,
    FormalParameterBuilder,
    KernelConstructorBuilder,
    KernelFieldBuilder,
    KernelFormalParameterBuilder,
    KernelInterfaceTypeBuilder,
    KernelLibraryBuilder,
    KernelProcedureBuilder,
    KernelTypeBuilder,
    LibraryBuilder,
    MemberBuilder,
    MetadataBuilder;

class KernelEnumBuilder extends SourceClassBuilder
    implements EnumBuilder<KernelTypeBuilder, InterfaceType> {
  final List<String> constants;

  final MapLiteral toStringMap;

  final KernelTypeBuilder intType;

  final KernelTypeBuilder stringType;

  KernelEnumBuilder.internal(List<MetadataBuilder> metadata, String name,
      Map<String, Builder> members, List<KernelTypeBuilder> types, Class cls,
      this.constants, this.toStringMap, this.intType, this.stringType,
      LibraryBuilder parent)
      : super(metadata, 0, name, null, null, null, members, types, parent, null,
          cls);

  factory KernelEnumBuilder(List<MetadataBuilder> metadata, String name,
      List<String> constants, LibraryBuilder parent) {
    constants ??= const <String>[];
    // TODO(ahe): These types shouldn't be looked up in scope, they come
    // directly from dart:core.
    KernelTypeBuilder objectType =
        new KernelInterfaceTypeBuilder("Object", null);
    KernelTypeBuilder intType =
        new KernelInterfaceTypeBuilder("int", null);
    KernelTypeBuilder stringType =
        new KernelInterfaceTypeBuilder("String", null);
    List<KernelTypeBuilder> types = <KernelTypeBuilder>[
        objectType,
        intType,
        stringType];
    Class cls = new Class(name: name);
    Map<String, Builder> members = <String, Builder>{};
    KernelInterfaceTypeBuilder selfType = new KernelInterfaceTypeBuilder(
        name, null);
    KernelTypeBuilder listType =
        new KernelInterfaceTypeBuilder("List", <KernelTypeBuilder>[selfType]);
    types.add(listType);

    /// From Dart Programming Language Specification 4th Edition/December 2015:
    ///     metadata class E {
    ///       final int index;
    ///       const E(this.index);
    ///       static const E id0 = const E(0);
    ///       ...
    ///       static const E idn-1 = const E(n - 1);
    ///       static const List<E> values = const <E>[id0, ..., idn-1];
    ///       String toString() => { 0: ‘E.id0’, . . ., n-1: ‘E.idn-1’}[index]
    ///     }
    members["index"] =
        new KernelFieldBuilder(null, intType, "index", finalMask);
    KernelConstructorBuilder constructorBuilder = new KernelConstructorBuilder(
        null, constMask, null, "", null, <FormalParameterBuilder>[
            new KernelFormalParameterBuilder(null, 0, intType, "index", true)]);
    members[""] = constructorBuilder;
    int index = 0;
    List<MapEntry> toStringEntries = <MapEntry>[];
    KernelFieldBuilder valuesBuilder = new KernelFieldBuilder(null, listType,
        "values", constMask | staticMask);
    members["values"] = valuesBuilder;
    KernelProcedureBuilder toStringBuilder = new KernelProcedureBuilder(null, 0,
        stringType, "toString", null, null, AsyncMarker.Sync,
        ProcedureKind.Method);
    members["toString"] = toStringBuilder;
    String className = name;
    for (String name in constants) {
      if (members.containsKey(name)) {
        inputError(null, null, "Duplicated name: $name");
        continue;
      }
      KernelFieldBuilder fieldBuilder =
          new KernelFieldBuilder(null, selfType, name, constMask | staticMask);
      members[name] = fieldBuilder;
      toStringEntries.add(new MapEntry(
              new IntLiteral(index), new StringLiteral("$className.$name")));
      index++;
    }
    MapLiteral toStringMap = new MapLiteral(toStringEntries, isConst: true);
    KernelEnumBuilder enumBuilder = new KernelEnumBuilder.internal(metadata,
        name, members, types, cls, constants, toStringMap, intType, stringType,
        parent);
    members.forEach((String name, MemberBuilder builder) {
      builder.parent = enumBuilder;
    });
    selfType.builder = enumBuilder;
    return enumBuilder;
  }

  InterfaceType buildType(List<KernelTypeBuilder> arguments) {
    return cls.rawType;
  }

  Class build(KernelLibraryBuilder libraryBuilder) {
    if (constants.isEmpty) {
      libraryBuilder.addCompileTimeError(
          -1, "An enum declaration can't be empty.");
    }
    toStringMap.keyType = intType.build();
    toStringMap.valueType = stringType.build();
    KernelFieldBuilder indexFieldBuilder = members["index"];
    Field indexField = indexFieldBuilder.build(libraryBuilder.library);
    KernelProcedureBuilder toStringBuilder = members["toString"];
    toStringBuilder.body = new ReturnStatement(
        new MethodInvocation(toStringMap, new Name("[]"),
            new Arguments(<Expression>[
                    new DirectPropertyGet(new ThisExpression(), indexField)])));
    List<Expression> values = <Expression>[];
    for (String name in constants) {
      KernelFieldBuilder builder = members[name];
      values.add(new StaticGet(builder.build(libraryBuilder.library)));
    }
    KernelFieldBuilder valuesBuilder = members["values"];
    valuesBuilder.build(libraryBuilder.library);
    valuesBuilder.initializer =
        new ListLiteral(values, typeArgument: cls.rawType, isConst: true);
    KernelConstructorBuilder constructorBuilder = members[""];
    Constructor constructor = constructorBuilder.build(libraryBuilder.library);
    constructor.initializers.insert(0, new FieldInitializer(indexField,
            new VariableGet(constructor.function.positionalParameters.single))
        ..parent = constructor);
    int index = 0;
    for (String constant in constants) {
      KernelFieldBuilder field = members[constant];
      field.build(libraryBuilder.library);
      Arguments arguments =
          new Arguments(<Expression>[new IntLiteral(index++)]);
      field.initializer =
          new ConstructorInvocation(constructor, arguments, isConst: true);
    }
    return super.build(libraryBuilder);
  }

  Builder findConstructorOrFactory(String name) => null;
}
