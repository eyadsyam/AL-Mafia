// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_group_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPlayerGroupRecordCollection on Isar {
  IsarCollection<PlayerGroupRecord> get playerGroupRecords => this.collection();
}

const PlayerGroupRecordSchema = CollectionSchema(
  name: r'PlayerGroupRecord',
  id: 4002796305643377676,
  properties: {
    r'lastPlayedAt': PropertySchema(
      id: 0,
      name: r'lastPlayedAt',
      type: IsarType.dateTime,
    ),
    r'payload': PropertySchema(id: 1, name: r'payload', type: IsarType.string),
  },

  estimateSize: _playerGroupRecordEstimateSize,
  serialize: _playerGroupRecordSerialize,
  deserialize: _playerGroupRecordDeserialize,
  deserializeProp: _playerGroupRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'lastPlayedAt': IndexSchema(
      id: 1709968845012040220,
      name: r'lastPlayedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'lastPlayedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _playerGroupRecordGetId,
  getLinks: _playerGroupRecordGetLinks,
  attach: _playerGroupRecordAttach,
  version: '3.3.2',
);

int _playerGroupRecordEstimateSize(
  PlayerGroupRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.payload.length * 3;
  return bytesCount;
}

void _playerGroupRecordSerialize(
  PlayerGroupRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.lastPlayedAt);
  writer.writeString(offsets[1], object.payload);
}

PlayerGroupRecord _playerGroupRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PlayerGroupRecord();
  object.id = id;
  object.lastPlayedAt = reader.readDateTime(offsets[0]);
  object.payload = reader.readString(offsets[1]);
  return object;
}

P _playerGroupRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _playerGroupRecordGetId(PlayerGroupRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _playerGroupRecordGetLinks(
  PlayerGroupRecord object,
) {
  return [];
}

void _playerGroupRecordAttach(
  IsarCollection<dynamic> col,
  Id id,
  PlayerGroupRecord object,
) {
  object.id = id;
}

extension PlayerGroupRecordQueryWhereSort
    on QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QWhere> {
  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhere>
  anyLastPlayedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'lastPlayedAt'),
      );
    });
  }
}

extension PlayerGroupRecordQueryWhere
    on QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QWhereClause> {
  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhereClause>
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

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhereClause>
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

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhereClause>
  lastPlayedAtEqualTo(DateTime lastPlayedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'lastPlayedAt',
          value: [lastPlayedAt],
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhereClause>
  lastPlayedAtNotEqualTo(DateTime lastPlayedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastPlayedAt',
                lower: [],
                upper: [lastPlayedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastPlayedAt',
                lower: [lastPlayedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastPlayedAt',
                lower: [lastPlayedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastPlayedAt',
                lower: [],
                upper: [lastPlayedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhereClause>
  lastPlayedAtGreaterThan(DateTime lastPlayedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastPlayedAt',
          lower: [lastPlayedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhereClause>
  lastPlayedAtLessThan(DateTime lastPlayedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastPlayedAt',
          lower: [],
          upper: [lastPlayedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterWhereClause>
  lastPlayedAtBetween(
    DateTime lowerLastPlayedAt,
    DateTime upperLastPlayedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastPlayedAt',
          lower: [lowerLastPlayedAt],
          includeLower: includeLower,
          upper: [upperLastPlayedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension PlayerGroupRecordQueryFilter
    on QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QFilterCondition> {
  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
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

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
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

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
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

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  lastPlayedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastPlayedAt', value: value),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  lastPlayedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastPlayedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  lastPlayedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastPlayedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  lastPlayedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastPlayedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  payloadEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'payload',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  payloadGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'payload',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  payloadLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'payload',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  payloadBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'payload',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  payloadStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'payload',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  payloadEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'payload',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  payloadContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'payload',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  payloadMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'payload',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  payloadIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'payload', value: ''),
      );
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterFilterCondition>
  payloadIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'payload', value: ''),
      );
    });
  }
}

extension PlayerGroupRecordQueryObject
    on QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QFilterCondition> {}

extension PlayerGroupRecordQueryLinks
    on QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QFilterCondition> {}

extension PlayerGroupRecordQuerySortBy
    on QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QSortBy> {
  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterSortBy>
  sortByLastPlayedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPlayedAt', Sort.asc);
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterSortBy>
  sortByLastPlayedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPlayedAt', Sort.desc);
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterSortBy>
  sortByPayload() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload', Sort.asc);
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterSortBy>
  sortByPayloadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload', Sort.desc);
    });
  }
}

extension PlayerGroupRecordQuerySortThenBy
    on QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QSortThenBy> {
  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterSortBy>
  thenByLastPlayedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPlayedAt', Sort.asc);
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterSortBy>
  thenByLastPlayedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPlayedAt', Sort.desc);
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterSortBy>
  thenByPayload() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload', Sort.asc);
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QAfterSortBy>
  thenByPayloadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload', Sort.desc);
    });
  }
}

extension PlayerGroupRecordQueryWhereDistinct
    on QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QDistinct> {
  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QDistinct>
  distinctByLastPlayedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastPlayedAt');
    });
  }

  QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QDistinct>
  distinctByPayload({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payload', caseSensitive: caseSensitive);
    });
  }
}

extension PlayerGroupRecordQueryProperty
    on QueryBuilder<PlayerGroupRecord, PlayerGroupRecord, QQueryProperty> {
  QueryBuilder<PlayerGroupRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PlayerGroupRecord, DateTime, QQueryOperations>
  lastPlayedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastPlayedAt');
    });
  }

  QueryBuilder<PlayerGroupRecord, String, QQueryOperations> payloadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payload');
    });
  }
}
