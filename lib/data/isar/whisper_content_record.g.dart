// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whisper_content_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWhisperContentRecordCollection on Isar {
  IsarCollection<WhisperContentRecord> get whisperContentRecords =>
      this.collection();
}

const WhisperContentRecordSchema = CollectionSchema(
  name: r'WhisperContentRecord',
  id: -23006770423193268,
  properties: {
    r'body': PropertySchema(id: 0, name: r'body', type: IsarType.string),
    r'matchId': PropertySchema(id: 1, name: r'matchId', type: IsarType.long),
    r'whisperId': PropertySchema(
      id: 2,
      name: r'whisperId',
      type: IsarType.string,
    ),
  },

  estimateSize: _whisperContentRecordEstimateSize,
  serialize: _whisperContentRecordSerialize,
  deserialize: _whisperContentRecordDeserialize,
  deserializeProp: _whisperContentRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'matchId_whisperId': IndexSchema(
      id: -8826017818104028957,
      name: r'matchId_whisperId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'matchId',
          type: IndexType.value,
          caseSensitive: false,
        ),
        IndexPropertySchema(
          name: r'whisperId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _whisperContentRecordGetId,
  getLinks: _whisperContentRecordGetLinks,
  attach: _whisperContentRecordAttach,
  version: '3.3.2',
);

int _whisperContentRecordEstimateSize(
  WhisperContentRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.body.length * 3;
  bytesCount += 3 + object.whisperId.length * 3;
  return bytesCount;
}

void _whisperContentRecordSerialize(
  WhisperContentRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.body);
  writer.writeLong(offsets[1], object.matchId);
  writer.writeString(offsets[2], object.whisperId);
}

WhisperContentRecord _whisperContentRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WhisperContentRecord();
  object.body = reader.readString(offsets[0]);
  object.id = id;
  object.matchId = reader.readLong(offsets[1]);
  object.whisperId = reader.readString(offsets[2]);
  return object;
}

P _whisperContentRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _whisperContentRecordGetId(WhisperContentRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _whisperContentRecordGetLinks(
  WhisperContentRecord object,
) {
  return [];
}

void _whisperContentRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  WhisperContentRecord object,
) {
  object.id = id;
}

extension WhisperContentRecordByIndex on IsarCollection<WhisperContentRecord> {
  Future<WhisperContentRecord?> getByMatchIdWhisperId(
    int matchId,
    String whisperId,
  ) {
    return getByIndex(r'matchId_whisperId', [matchId, whisperId]);
  }

  WhisperContentRecord? getByMatchIdWhisperIdSync(
    int matchId,
    String whisperId,
  ) {
    return getByIndexSync(r'matchId_whisperId', [matchId, whisperId]);
  }

  Future<bool> deleteByMatchIdWhisperId(int matchId, String whisperId) {
    return deleteByIndex(r'matchId_whisperId', [matchId, whisperId]);
  }

  bool deleteByMatchIdWhisperIdSync(int matchId, String whisperId) {
    return deleteByIndexSync(r'matchId_whisperId', [matchId, whisperId]);
  }

  Future<List<WhisperContentRecord?>> getAllByMatchIdWhisperId(
    List<int> matchIdValues,
    List<String> whisperIdValues,
  ) {
    final len = matchIdValues.length;
    assert(
      whisperIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([matchIdValues[i], whisperIdValues[i]]);
    }

    return getAllByIndex(r'matchId_whisperId', values);
  }

  List<WhisperContentRecord?> getAllByMatchIdWhisperIdSync(
    List<int> matchIdValues,
    List<String> whisperIdValues,
  ) {
    final len = matchIdValues.length;
    assert(
      whisperIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([matchIdValues[i], whisperIdValues[i]]);
    }

    return getAllByIndexSync(r'matchId_whisperId', values);
  }

  Future<int> deleteAllByMatchIdWhisperId(
    List<int> matchIdValues,
    List<String> whisperIdValues,
  ) {
    final len = matchIdValues.length;
    assert(
      whisperIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([matchIdValues[i], whisperIdValues[i]]);
    }

    return deleteAllByIndex(r'matchId_whisperId', values);
  }

  int deleteAllByMatchIdWhisperIdSync(
    List<int> matchIdValues,
    List<String> whisperIdValues,
  ) {
    final len = matchIdValues.length;
    assert(
      whisperIdValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([matchIdValues[i], whisperIdValues[i]]);
    }

    return deleteAllByIndexSync(r'matchId_whisperId', values);
  }

  Future<Id> putByMatchIdWhisperId(WhisperContentRecord object) {
    return putByIndex(r'matchId_whisperId', object);
  }

  Id putByMatchIdWhisperIdSync(
    WhisperContentRecord object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(r'matchId_whisperId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByMatchIdWhisperId(
    List<WhisperContentRecord> objects,
  ) {
    return putAllByIndex(r'matchId_whisperId', objects);
  }

  List<Id> putAllByMatchIdWhisperIdSync(
    List<WhisperContentRecord> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'matchId_whisperId',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension WhisperContentRecordQueryWhereSort
    on QueryBuilder<WhisperContentRecord, WhisperContentRecord, QWhere> {
  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension WhisperContentRecordQueryWhere
    on QueryBuilder<WhisperContentRecord, WhisperContentRecord, QWhereClause> {
  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  matchIdEqualToAnyWhisperId(int matchId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'matchId_whisperId',
          value: [matchId],
        ),
      );
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  matchIdNotEqualToAnyWhisperId(int matchId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'matchId_whisperId',
                lower: [],
                upper: [matchId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'matchId_whisperId',
                lower: [matchId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'matchId_whisperId',
                lower: [matchId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'matchId_whisperId',
                lower: [],
                upper: [matchId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  matchIdGreaterThanAnyWhisperId(int matchId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'matchId_whisperId',
          lower: [matchId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  matchIdLessThanAnyWhisperId(int matchId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'matchId_whisperId',
          lower: [],
          upper: [matchId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  matchIdBetweenAnyWhisperId(
    int lowerMatchId,
    int upperMatchId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'matchId_whisperId',
          lower: [lowerMatchId],
          includeLower: includeLower,
          upper: [upperMatchId],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  matchIdWhisperIdEqualTo(int matchId, String whisperId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'matchId_whisperId',
          value: [matchId, whisperId],
        ),
      );
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterWhereClause>
  matchIdEqualToWhisperIdNotEqualTo(int matchId, String whisperId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'matchId_whisperId',
                lower: [matchId],
                upper: [matchId, whisperId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'matchId_whisperId',
                lower: [matchId, whisperId],
                includeLower: false,
                upper: [matchId],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'matchId_whisperId',
                lower: [matchId, whisperId],
                includeLower: false,
                upper: [matchId],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'matchId_whisperId',
                lower: [matchId],
                upper: [matchId, whisperId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension WhisperContentRecordQueryFilter
    on
        QueryBuilder<
          WhisperContentRecord,
          WhisperContentRecord,
          QFilterCondition
        > {
  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  bodyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'body',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  bodyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'body',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  bodyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'body',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  bodyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'body',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  bodyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'body',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  bodyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'body',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  bodyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'body',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  bodyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'body',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  bodyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'body', value: ''),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  bodyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'body', value: ''),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  matchIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'matchId', value: value),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  matchIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'matchId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  matchIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'matchId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  matchIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'matchId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  whisperIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'whisperId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  whisperIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'whisperId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  whisperIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'whisperId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  whisperIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'whisperId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  whisperIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'whisperId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  whisperIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'whisperId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  whisperIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'whisperId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  whisperIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'whisperId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  whisperIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'whisperId', value: ''),
      );
    });
  }

  QueryBuilder<
    WhisperContentRecord,
    WhisperContentRecord,
    QAfterFilterCondition
  >
  whisperIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'whisperId', value: ''),
      );
    });
  }
}

extension WhisperContentRecordQueryObject
    on
        QueryBuilder<
          WhisperContentRecord,
          WhisperContentRecord,
          QFilterCondition
        > {}

extension WhisperContentRecordQueryLinks
    on
        QueryBuilder<
          WhisperContentRecord,
          WhisperContentRecord,
          QFilterCondition
        > {}

extension WhisperContentRecordQuerySortBy
    on QueryBuilder<WhisperContentRecord, WhisperContentRecord, QSortBy> {
  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  sortByBody() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body', Sort.asc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  sortByBodyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body', Sort.desc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  sortByMatchId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchId', Sort.asc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  sortByMatchIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchId', Sort.desc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  sortByWhisperId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'whisperId', Sort.asc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  sortByWhisperIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'whisperId', Sort.desc);
    });
  }
}

extension WhisperContentRecordQuerySortThenBy
    on QueryBuilder<WhisperContentRecord, WhisperContentRecord, QSortThenBy> {
  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  thenByBody() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body', Sort.asc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  thenByBodyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'body', Sort.desc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  thenByMatchId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchId', Sort.asc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  thenByMatchIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'matchId', Sort.desc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  thenByWhisperId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'whisperId', Sort.asc);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QAfterSortBy>
  thenByWhisperIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'whisperId', Sort.desc);
    });
  }
}

extension WhisperContentRecordQueryWhereDistinct
    on QueryBuilder<WhisperContentRecord, WhisperContentRecord, QDistinct> {
  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QDistinct>
  distinctByBody({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'body', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QDistinct>
  distinctByMatchId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'matchId');
    });
  }

  QueryBuilder<WhisperContentRecord, WhisperContentRecord, QDistinct>
  distinctByWhisperId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'whisperId', caseSensitive: caseSensitive);
    });
  }
}

extension WhisperContentRecordQueryProperty
    on
        QueryBuilder<
          WhisperContentRecord,
          WhisperContentRecord,
          QQueryProperty
        > {
  QueryBuilder<WhisperContentRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WhisperContentRecord, String, QQueryOperations> bodyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'body');
    });
  }

  QueryBuilder<WhisperContentRecord, int, QQueryOperations> matchIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'matchId');
    });
  }

  QueryBuilder<WhisperContentRecord, String, QQueryOperations>
  whisperIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'whisperId');
    });
  }
}
