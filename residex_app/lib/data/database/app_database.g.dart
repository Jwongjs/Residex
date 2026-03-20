// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarInitialsMeta = const VerificationMeta(
    'avatarInitials',
  );
  @override
  late final GeneratedColumn<String> avatarInitials = GeneratedColumn<String>(
    'avatar_initials',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileImageMeta = const VerificationMeta(
    'profileImage',
  );
  @override
  late final GeneratedColumn<String> profileImage = GeneratedColumn<String>(
    'profile_image',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gradientColorValuesMeta =
      const VerificationMeta('gradientColorValues');
  @override
  late final GeneratedColumn<String> gradientColorValues =
      GeneratedColumn<String>(
        'gradient_color_values',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isGuestMeta = const VerificationMeta(
    'isGuest',
  );
  @override
  late final GeneratedColumn<bool> isGuest = GeneratedColumn<bool>(
    'is_guest',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_guest" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _phoneNumberMeta = const VerificationMeta(
    'phoneNumber',
  );
  @override
  late final GeneratedColumn<String> phoneNumber = GeneratedColumn<String>(
    'phone_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    avatarInitials,
    profileImage,
    gradientColorValues,
    isGuest,
    phoneNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar_initials')) {
      context.handle(
        _avatarInitialsMeta,
        avatarInitials.isAcceptableOrUnknown(
          data['avatar_initials']!,
          _avatarInitialsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_avatarInitialsMeta);
    }
    if (data.containsKey('profile_image')) {
      context.handle(
        _profileImageMeta,
        profileImage.isAcceptableOrUnknown(
          data['profile_image']!,
          _profileImageMeta,
        ),
      );
    }
    if (data.containsKey('gradient_color_values')) {
      context.handle(
        _gradientColorValuesMeta,
        gradientColorValues.isAcceptableOrUnknown(
          data['gradient_color_values']!,
          _gradientColorValuesMeta,
        ),
      );
    }
    if (data.containsKey('is_guest')) {
      context.handle(
        _isGuestMeta,
        isGuest.isAcceptableOrUnknown(data['is_guest']!, _isGuestMeta),
      );
    }
    if (data.containsKey('phone_number')) {
      context.handle(
        _phoneNumberMeta,
        phoneNumber.isAcceptableOrUnknown(
          data['phone_number']!,
          _phoneNumberMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatarInitials: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_initials'],
      )!,
      profileImage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_image'],
      ),
      gradientColorValues: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gradient_color_values'],
      ),
      isGuest: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_guest'],
      )!,
      phoneNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone_number'],
      ),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String id;
  final String name;
  final String avatarInitials;
  final String? profileImage;
  final String? gradientColorValues;
  final bool isGuest;
  final String? phoneNumber;
  const User({
    required this.id,
    required this.name,
    required this.avatarInitials,
    this.profileImage,
    this.gradientColorValues,
    required this.isGuest,
    this.phoneNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['avatar_initials'] = Variable<String>(avatarInitials);
    if (!nullToAbsent || profileImage != null) {
      map['profile_image'] = Variable<String>(profileImage);
    }
    if (!nullToAbsent || gradientColorValues != null) {
      map['gradient_color_values'] = Variable<String>(gradientColorValues);
    }
    map['is_guest'] = Variable<bool>(isGuest);
    if (!nullToAbsent || phoneNumber != null) {
      map['phone_number'] = Variable<String>(phoneNumber);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      name: Value(name),
      avatarInitials: Value(avatarInitials),
      profileImage: profileImage == null && nullToAbsent
          ? const Value.absent()
          : Value(profileImage),
      gradientColorValues: gradientColorValues == null && nullToAbsent
          ? const Value.absent()
          : Value(gradientColorValues),
      isGuest: Value(isGuest),
      phoneNumber: phoneNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(phoneNumber),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatarInitials: serializer.fromJson<String>(json['avatarInitials']),
      profileImage: serializer.fromJson<String?>(json['profileImage']),
      gradientColorValues: serializer.fromJson<String?>(
        json['gradientColorValues'],
      ),
      isGuest: serializer.fromJson<bool>(json['isGuest']),
      phoneNumber: serializer.fromJson<String?>(json['phoneNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'avatarInitials': serializer.toJson<String>(avatarInitials),
      'profileImage': serializer.toJson<String?>(profileImage),
      'gradientColorValues': serializer.toJson<String?>(gradientColorValues),
      'isGuest': serializer.toJson<bool>(isGuest),
      'phoneNumber': serializer.toJson<String?>(phoneNumber),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? avatarInitials,
    Value<String?> profileImage = const Value.absent(),
    Value<String?> gradientColorValues = const Value.absent(),
    bool? isGuest,
    Value<String?> phoneNumber = const Value.absent(),
  }) => User(
    id: id ?? this.id,
    name: name ?? this.name,
    avatarInitials: avatarInitials ?? this.avatarInitials,
    profileImage: profileImage.present ? profileImage.value : this.profileImage,
    gradientColorValues: gradientColorValues.present
        ? gradientColorValues.value
        : this.gradientColorValues,
    isGuest: isGuest ?? this.isGuest,
    phoneNumber: phoneNumber.present ? phoneNumber.value : this.phoneNumber,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatarInitials: data.avatarInitials.present
          ? data.avatarInitials.value
          : this.avatarInitials,
      profileImage: data.profileImage.present
          ? data.profileImage.value
          : this.profileImage,
      gradientColorValues: data.gradientColorValues.present
          ? data.gradientColorValues.value
          : this.gradientColorValues,
      isGuest: data.isGuest.present ? data.isGuest.value : this.isGuest,
      phoneNumber: data.phoneNumber.present
          ? data.phoneNumber.value
          : this.phoneNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarInitials: $avatarInitials, ')
          ..write('profileImage: $profileImage, ')
          ..write('gradientColorValues: $gradientColorValues, ')
          ..write('isGuest: $isGuest, ')
          ..write('phoneNumber: $phoneNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    avatarInitials,
    profileImage,
    gradientColorValues,
    isGuest,
    phoneNumber,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatarInitials == this.avatarInitials &&
          other.profileImage == this.profileImage &&
          other.gradientColorValues == this.gradientColorValues &&
          other.isGuest == this.isGuest &&
          other.phoneNumber == this.phoneNumber);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> avatarInitials;
  final Value<String?> profileImage;
  final Value<String?> gradientColorValues;
  final Value<bool> isGuest;
  final Value<String?> phoneNumber;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarInitials = const Value.absent(),
    this.profileImage = const Value.absent(),
    this.gradientColorValues = const Value.absent(),
    this.isGuest = const Value.absent(),
    this.phoneNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    required String name,
    required String avatarInitials,
    this.profileImage = const Value.absent(),
    this.gradientColorValues = const Value.absent(),
    this.isGuest = const Value.absent(),
    this.phoneNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       avatarInitials = Value(avatarInitials);
  static Insertable<User> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? avatarInitials,
    Expression<String>? profileImage,
    Expression<String>? gradientColorValues,
    Expression<bool>? isGuest,
    Expression<String>? phoneNumber,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatarInitials != null) 'avatar_initials': avatarInitials,
      if (profileImage != null) 'profile_image': profileImage,
      if (gradientColorValues != null)
        'gradient_color_values': gradientColorValues,
      if (isGuest != null) 'is_guest': isGuest,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? avatarInitials,
    Value<String?>? profileImage,
    Value<String?>? gradientColorValues,
    Value<bool>? isGuest,
    Value<String?>? phoneNumber,
    Value<int>? rowid,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      profileImage: profileImage ?? this.profileImage,
      gradientColorValues: gradientColorValues ?? this.gradientColorValues,
      isGuest: isGuest ?? this.isGuest,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarInitials.present) {
      map['avatar_initials'] = Variable<String>(avatarInitials.value);
    }
    if (profileImage.present) {
      map['profile_image'] = Variable<String>(profileImage.value);
    }
    if (gradientColorValues.present) {
      map['gradient_color_values'] = Variable<String>(
        gradientColorValues.value,
      );
    }
    if (isGuest.present) {
      map['is_guest'] = Variable<bool>(isGuest.value);
    }
    if (phoneNumber.present) {
      map['phone_number'] = Variable<String>(phoneNumber.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarInitials: $avatarInitials, ')
          ..write('profileImage: $profileImage, ')
          ..write('gradientColorValues: $gradientColorValues, ')
          ..write('isGuest: $isGuest, ')
          ..write('phoneNumber: $phoneNumber, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupsTable extends Groups with TableInfo<$GroupsTable, Group> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tenantIdsMeta = const VerificationMeta(
    'tenantIds',
  );
  @override
  late final GeneratedColumn<String> tenantIds = GeneratedColumn<String>(
    'tenant_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _landlordIdMeta = const VerificationMeta(
    'landlordId',
  );
  @override
  late final GeneratedColumn<String> landlordId = GeneratedColumn<String>(
    'landlord_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseStartDateMeta = const VerificationMeta(
    'leaseStartDate',
  );
  @override
  late final GeneratedColumn<DateTime> leaseStartDate =
      GeneratedColumn<DateTime>(
        'lease_start_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _leaseEndDateMeta = const VerificationMeta(
    'leaseEndDate',
  );
  @override
  late final GeneratedColumn<DateTime> leaseEndDate = GeneratedColumn<DateTime>(
    'lease_end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    emoji,
    colorValue,
    createdBy,
    address,
    tenantIds,
    landlordId,
    leaseStartDate,
    leaseEndDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<Group> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('tenant_ids')) {
      context.handle(
        _tenantIdsMeta,
        tenantIds.isAcceptableOrUnknown(data['tenant_ids']!, _tenantIdsMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdsMeta);
    }
    if (data.containsKey('landlord_id')) {
      context.handle(
        _landlordIdMeta,
        landlordId.isAcceptableOrUnknown(data['landlord_id']!, _landlordIdMeta),
      );
    }
    if (data.containsKey('lease_start_date')) {
      context.handle(
        _leaseStartDateMeta,
        leaseStartDate.isAcceptableOrUnknown(
          data['lease_start_date']!,
          _leaseStartDateMeta,
        ),
      );
    }
    if (data.containsKey('lease_end_date')) {
      context.handle(
        _leaseEndDateMeta,
        leaseEndDate.isAcceptableOrUnknown(
          data['lease_end_date']!,
          _leaseEndDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Group map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Group(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      tenantIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_ids'],
      )!,
      landlordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}landlord_id'],
      ),
      leaseStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lease_start_date'],
      ),
      leaseEndDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lease_end_date'],
      ),
    );
  }

  @override
  $GroupsTable createAlias(String alias) {
    return $GroupsTable(attachedDatabase, alias);
  }
}

class Group extends DataClass implements Insertable<Group> {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final String? createdBy;
  final String? address;
  final String tenantIds;
  final String? landlordId;
  final DateTime? leaseStartDate;
  final DateTime? leaseEndDate;
  const Group({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    this.createdBy,
    this.address,
    required this.tenantIds,
    this.landlordId,
    this.leaseStartDate,
    this.leaseEndDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['emoji'] = Variable<String>(emoji);
    map['color_value'] = Variable<int>(colorValue);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    map['tenant_ids'] = Variable<String>(tenantIds);
    if (!nullToAbsent || landlordId != null) {
      map['landlord_id'] = Variable<String>(landlordId);
    }
    if (!nullToAbsent || leaseStartDate != null) {
      map['lease_start_date'] = Variable<DateTime>(leaseStartDate);
    }
    if (!nullToAbsent || leaseEndDate != null) {
      map['lease_end_date'] = Variable<DateTime>(leaseEndDate);
    }
    return map;
  }

  GroupsCompanion toCompanion(bool nullToAbsent) {
    return GroupsCompanion(
      id: Value(id),
      name: Value(name),
      emoji: Value(emoji),
      colorValue: Value(colorValue),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      tenantIds: Value(tenantIds),
      landlordId: landlordId == null && nullToAbsent
          ? const Value.absent()
          : Value(landlordId),
      leaseStartDate: leaseStartDate == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseStartDate),
      leaseEndDate: leaseEndDate == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseEndDate),
    );
  }

  factory Group.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Group(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      emoji: serializer.fromJson<String>(json['emoji']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      address: serializer.fromJson<String?>(json['address']),
      tenantIds: serializer.fromJson<String>(json['tenantIds']),
      landlordId: serializer.fromJson<String?>(json['landlordId']),
      leaseStartDate: serializer.fromJson<DateTime?>(json['leaseStartDate']),
      leaseEndDate: serializer.fromJson<DateTime?>(json['leaseEndDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'emoji': serializer.toJson<String>(emoji),
      'colorValue': serializer.toJson<int>(colorValue),
      'createdBy': serializer.toJson<String?>(createdBy),
      'address': serializer.toJson<String?>(address),
      'tenantIds': serializer.toJson<String>(tenantIds),
      'landlordId': serializer.toJson<String?>(landlordId),
      'leaseStartDate': serializer.toJson<DateTime?>(leaseStartDate),
      'leaseEndDate': serializer.toJson<DateTime?>(leaseEndDate),
    };
  }

  Group copyWith({
    String? id,
    String? name,
    String? emoji,
    int? colorValue,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> address = const Value.absent(),
    String? tenantIds,
    Value<String?> landlordId = const Value.absent(),
    Value<DateTime?> leaseStartDate = const Value.absent(),
    Value<DateTime?> leaseEndDate = const Value.absent(),
  }) => Group(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    colorValue: colorValue ?? this.colorValue,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    address: address.present ? address.value : this.address,
    tenantIds: tenantIds ?? this.tenantIds,
    landlordId: landlordId.present ? landlordId.value : this.landlordId,
    leaseStartDate: leaseStartDate.present
        ? leaseStartDate.value
        : this.leaseStartDate,
    leaseEndDate: leaseEndDate.present ? leaseEndDate.value : this.leaseEndDate,
  );
  Group copyWithCompanion(GroupsCompanion data) {
    return Group(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      address: data.address.present ? data.address.value : this.address,
      tenantIds: data.tenantIds.present ? data.tenantIds.value : this.tenantIds,
      landlordId: data.landlordId.present
          ? data.landlordId.value
          : this.landlordId,
      leaseStartDate: data.leaseStartDate.present
          ? data.leaseStartDate.value
          : this.leaseStartDate,
      leaseEndDate: data.leaseEndDate.present
          ? data.leaseEndDate.value
          : this.leaseEndDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Group(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdBy: $createdBy, ')
          ..write('address: $address, ')
          ..write('tenantIds: $tenantIds, ')
          ..write('landlordId: $landlordId, ')
          ..write('leaseStartDate: $leaseStartDate, ')
          ..write('leaseEndDate: $leaseEndDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    emoji,
    colorValue,
    createdBy,
    address,
    tenantIds,
    landlordId,
    leaseStartDate,
    leaseEndDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Group &&
          other.id == this.id &&
          other.name == this.name &&
          other.emoji == this.emoji &&
          other.colorValue == this.colorValue &&
          other.createdBy == this.createdBy &&
          other.address == this.address &&
          other.tenantIds == this.tenantIds &&
          other.landlordId == this.landlordId &&
          other.leaseStartDate == this.leaseStartDate &&
          other.leaseEndDate == this.leaseEndDate);
}

class GroupsCompanion extends UpdateCompanion<Group> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> emoji;
  final Value<int> colorValue;
  final Value<String?> createdBy;
  final Value<String?> address;
  final Value<String> tenantIds;
  final Value<String?> landlordId;
  final Value<DateTime?> leaseStartDate;
  final Value<DateTime?> leaseEndDate;
  final Value<int> rowid;
  const GroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.emoji = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.address = const Value.absent(),
    this.tenantIds = const Value.absent(),
    this.landlordId = const Value.absent(),
    this.leaseStartDate = const Value.absent(),
    this.leaseEndDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsCompanion.insert({
    required String id,
    required String name,
    required String emoji,
    required int colorValue,
    this.createdBy = const Value.absent(),
    this.address = const Value.absent(),
    required String tenantIds,
    this.landlordId = const Value.absent(),
    this.leaseStartDate = const Value.absent(),
    this.leaseEndDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       emoji = Value(emoji),
       colorValue = Value(colorValue),
       tenantIds = Value(tenantIds);
  static Insertable<Group> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? emoji,
    Expression<int>? colorValue,
    Expression<String>? createdBy,
    Expression<String>? address,
    Expression<String>? tenantIds,
    Expression<String>? landlordId,
    Expression<DateTime>? leaseStartDate,
    Expression<DateTime>? leaseEndDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (colorValue != null) 'color_value': colorValue,
      if (createdBy != null) 'created_by': createdBy,
      if (address != null) 'address': address,
      if (tenantIds != null) 'tenant_ids': tenantIds,
      if (landlordId != null) 'landlord_id': landlordId,
      if (leaseStartDate != null) 'lease_start_date': leaseStartDate,
      if (leaseEndDate != null) 'lease_end_date': leaseEndDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? emoji,
    Value<int>? colorValue,
    Value<String?>? createdBy,
    Value<String?>? address,
    Value<String>? tenantIds,
    Value<String?>? landlordId,
    Value<DateTime?>? leaseStartDate,
    Value<DateTime?>? leaseEndDate,
    Value<int>? rowid,
  }) {
    return GroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
      createdBy: createdBy ?? this.createdBy,
      address: address ?? this.address,
      tenantIds: tenantIds ?? this.tenantIds,
      landlordId: landlordId ?? this.landlordId,
      leaseStartDate: leaseStartDate ?? this.leaseStartDate,
      leaseEndDate: leaseEndDate ?? this.leaseEndDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (tenantIds.present) {
      map['tenant_ids'] = Variable<String>(tenantIds.value);
    }
    if (landlordId.present) {
      map['landlord_id'] = Variable<String>(landlordId.value);
    }
    if (leaseStartDate.present) {
      map['lease_start_date'] = Variable<DateTime>(leaseStartDate.value);
    }
    if (leaseEndDate.present) {
      map['lease_end_date'] = Variable<DateTime>(leaseEndDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('colorValue: $colorValue, ')
          ..write('createdBy: $createdBy, ')
          ..write('address: $address, ')
          ..write('tenantIds: $tenantIds, ')
          ..write('landlordId: $landlordId, ')
          ..write('leaseStartDate: $leaseStartDate, ')
          ..write('leaseEndDate: $leaseEndDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BillsTable extends Bills with TableInfo<$BillsTable, Bill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalAmountMeta = const VerificationMeta(
    'totalAmount',
  );
  @override
  late final GeneratedColumn<double> totalAmount = GeneratedColumn<double>(
    'total_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _participantIdsMeta = const VerificationMeta(
    'participantIds',
  );
  @override
  late final GeneratedColumn<String> participantIds = GeneratedColumn<String>(
    'participant_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _participantSharesMeta = const VerificationMeta(
    'participantShares',
  );
  @override
  late final GeneratedColumn<String> participantShares =
      GeneratedColumn<String>(
        'participant_shares',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _paymentStatusMeta = const VerificationMeta(
    'paymentStatus',
  );
  @override
  late final GeneratedColumn<String> paymentStatus = GeneratedColumn<String>(
    'payment_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    location,
    totalAmount,
    createdAt,
    participantIds,
    participantShares,
    paymentStatus,
    imageUrl,
    category,
    provider,
    dueDate,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bill> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    } else if (isInserting) {
      context.missing(_locationMeta);
    }
    if (data.containsKey('total_amount')) {
      context.handle(
        _totalAmountMeta,
        totalAmount.isAcceptableOrUnknown(
          data['total_amount']!,
          _totalAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('participant_ids')) {
      context.handle(
        _participantIdsMeta,
        participantIds.isAcceptableOrUnknown(
          data['participant_ids']!,
          _participantIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_participantIdsMeta);
    }
    if (data.containsKey('participant_shares')) {
      context.handle(
        _participantSharesMeta,
        participantShares.isAcceptableOrUnknown(
          data['participant_shares']!,
          _participantSharesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_participantSharesMeta);
    }
    if (data.containsKey('payment_status')) {
      context.handle(
        _paymentStatusMeta,
        paymentStatus.isAcceptableOrUnknown(
          data['payment_status']!,
          _paymentStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentStatusMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bill(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      totalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_amount'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      participantIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}participant_ids'],
      )!,
      participantShares: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}participant_shares'],
      )!,
      paymentStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_status'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $BillsTable createAlias(String alias) {
    return $BillsTable(attachedDatabase, alias);
  }
}

class Bill extends DataClass implements Insertable<Bill> {
  final String id;
  final String title;
  final String location;
  final double totalAmount;
  final DateTime createdAt;
  final String participantIds;
  final String participantShares;
  final String paymentStatus;
  final String? imageUrl;
  final String category;
  final String provider;
  final DateTime? dueDate;
  final String status;
  const Bill({
    required this.id,
    required this.title,
    required this.location,
    required this.totalAmount,
    required this.createdAt,
    required this.participantIds,
    required this.participantShares,
    required this.paymentStatus,
    this.imageUrl,
    required this.category,
    required this.provider,
    this.dueDate,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['location'] = Variable<String>(location);
    map['total_amount'] = Variable<double>(totalAmount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['participant_ids'] = Variable<String>(participantIds);
    map['participant_shares'] = Variable<String>(participantShares);
    map['payment_status'] = Variable<String>(paymentStatus);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['category'] = Variable<String>(category);
    map['provider'] = Variable<String>(provider);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  BillsCompanion toCompanion(bool nullToAbsent) {
    return BillsCompanion(
      id: Value(id),
      title: Value(title),
      location: Value(location),
      totalAmount: Value(totalAmount),
      createdAt: Value(createdAt),
      participantIds: Value(participantIds),
      participantShares: Value(participantShares),
      paymentStatus: Value(paymentStatus),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      category: Value(category),
      provider: Value(provider),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      status: Value(status),
    );
  }

  factory Bill.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bill(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      location: serializer.fromJson<String>(json['location']),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      participantIds: serializer.fromJson<String>(json['participantIds']),
      participantShares: serializer.fromJson<String>(json['participantShares']),
      paymentStatus: serializer.fromJson<String>(json['paymentStatus']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      category: serializer.fromJson<String>(json['category']),
      provider: serializer.fromJson<String>(json['provider']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'location': serializer.toJson<String>(location),
      'totalAmount': serializer.toJson<double>(totalAmount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'participantIds': serializer.toJson<String>(participantIds),
      'participantShares': serializer.toJson<String>(participantShares),
      'paymentStatus': serializer.toJson<String>(paymentStatus),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'category': serializer.toJson<String>(category),
      'provider': serializer.toJson<String>(provider),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'status': serializer.toJson<String>(status),
    };
  }

  Bill copyWith({
    String? id,
    String? title,
    String? location,
    double? totalAmount,
    DateTime? createdAt,
    String? participantIds,
    String? participantShares,
    String? paymentStatus,
    Value<String?> imageUrl = const Value.absent(),
    String? category,
    String? provider,
    Value<DateTime?> dueDate = const Value.absent(),
    String? status,
  }) => Bill(
    id: id ?? this.id,
    title: title ?? this.title,
    location: location ?? this.location,
    totalAmount: totalAmount ?? this.totalAmount,
    createdAt: createdAt ?? this.createdAt,
    participantIds: participantIds ?? this.participantIds,
    participantShares: participantShares ?? this.participantShares,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    category: category ?? this.category,
    provider: provider ?? this.provider,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    status: status ?? this.status,
  );
  Bill copyWithCompanion(BillsCompanion data) {
    return Bill(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      location: data.location.present ? data.location.value : this.location,
      totalAmount: data.totalAmount.present
          ? data.totalAmount.value
          : this.totalAmount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      participantIds: data.participantIds.present
          ? data.participantIds.value
          : this.participantIds,
      participantShares: data.participantShares.present
          ? data.participantShares.value
          : this.participantShares,
      paymentStatus: data.paymentStatus.present
          ? data.paymentStatus.value
          : this.paymentStatus,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      category: data.category.present ? data.category.value : this.category,
      provider: data.provider.present ? data.provider.value : this.provider,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bill(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('location: $location, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('createdAt: $createdAt, ')
          ..write('participantIds: $participantIds, ')
          ..write('participantShares: $participantShares, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('category: $category, ')
          ..write('provider: $provider, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    location,
    totalAmount,
    createdAt,
    participantIds,
    participantShares,
    paymentStatus,
    imageUrl,
    category,
    provider,
    dueDate,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bill &&
          other.id == this.id &&
          other.title == this.title &&
          other.location == this.location &&
          other.totalAmount == this.totalAmount &&
          other.createdAt == this.createdAt &&
          other.participantIds == this.participantIds &&
          other.participantShares == this.participantShares &&
          other.paymentStatus == this.paymentStatus &&
          other.imageUrl == this.imageUrl &&
          other.category == this.category &&
          other.provider == this.provider &&
          other.dueDate == this.dueDate &&
          other.status == this.status);
}

class BillsCompanion extends UpdateCompanion<Bill> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> location;
  final Value<double> totalAmount;
  final Value<DateTime> createdAt;
  final Value<String> participantIds;
  final Value<String> participantShares;
  final Value<String> paymentStatus;
  final Value<String?> imageUrl;
  final Value<String> category;
  final Value<String> provider;
  final Value<DateTime?> dueDate;
  final Value<String> status;
  final Value<int> rowid;
  const BillsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.location = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.participantIds = const Value.absent(),
    this.participantShares = const Value.absent(),
    this.paymentStatus = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.category = const Value.absent(),
    this.provider = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BillsCompanion.insert({
    required String id,
    required String title,
    required String location,
    required double totalAmount,
    required DateTime createdAt,
    required String participantIds,
    required String participantShares,
    required String paymentStatus,
    this.imageUrl = const Value.absent(),
    this.category = const Value.absent(),
    this.provider = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       location = Value(location),
       totalAmount = Value(totalAmount),
       createdAt = Value(createdAt),
       participantIds = Value(participantIds),
       participantShares = Value(participantShares),
       paymentStatus = Value(paymentStatus);
  static Insertable<Bill> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? location,
    Expression<double>? totalAmount,
    Expression<DateTime>? createdAt,
    Expression<String>? participantIds,
    Expression<String>? participantShares,
    Expression<String>? paymentStatus,
    Expression<String>? imageUrl,
    Expression<String>? category,
    Expression<String>? provider,
    Expression<DateTime>? dueDate,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (location != null) 'location': location,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (createdAt != null) 'created_at': createdAt,
      if (participantIds != null) 'participant_ids': participantIds,
      if (participantShares != null) 'participant_shares': participantShares,
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (imageUrl != null) 'image_url': imageUrl,
      if (category != null) 'category': category,
      if (provider != null) 'provider': provider,
      if (dueDate != null) 'due_date': dueDate,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BillsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? location,
    Value<double>? totalAmount,
    Value<DateTime>? createdAt,
    Value<String>? participantIds,
    Value<String>? participantShares,
    Value<String>? paymentStatus,
    Value<String?>? imageUrl,
    Value<String>? category,
    Value<String>? provider,
    Value<DateTime?>? dueDate,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return BillsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      participantIds: participantIds ?? this.participantIds,
      participantShares: participantShares ?? this.participantShares,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      provider: provider ?? this.provider,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (participantIds.present) {
      map['participant_ids'] = Variable<String>(participantIds.value);
    }
    if (participantShares.present) {
      map['participant_shares'] = Variable<String>(participantShares.value);
    }
    if (paymentStatus.present) {
      map['payment_status'] = Variable<String>(paymentStatus.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('location: $location, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('createdAt: $createdAt, ')
          ..write('participantIds: $participantIds, ')
          ..write('participantShares: $participantShares, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('category: $category, ')
          ..write('provider: $provider, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReceiptItemsTable extends ReceiptItems
    with TableInfo<$ReceiptItemsTable, ReceiptItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _billIdMeta = const VerificationMeta('billId');
  @override
  late final GeneratedColumn<String> billId = GeneratedColumn<String>(
    'bill_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taxRateMeta = const VerificationMeta(
    'taxRate',
  );
  @override
  late final GeneratedColumn<double> taxRate = GeneratedColumn<double>(
    'tax_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    billId,
    name,
    quantity,
    price,
    type,
    taxRate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipt_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReceiptItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bill_id')) {
      context.handle(
        _billIdMeta,
        billId.isAcceptableOrUnknown(data['bill_id']!, _billIdMeta),
      );
    } else if (isInserting) {
      context.missing(_billIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('tax_rate')) {
      context.handle(
        _taxRateMeta,
        taxRate.isAcceptableOrUnknown(data['tax_rate']!, _taxRateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReceiptItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      billId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bill_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      taxRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tax_rate'],
      ),
    );
  }

  @override
  $ReceiptItemsTable createAlias(String alias) {
    return $ReceiptItemsTable(attachedDatabase, alias);
  }
}

class ReceiptItem extends DataClass implements Insertable<ReceiptItem> {
  final String id;
  final String billId;
  final String name;
  final int quantity;
  final double price;
  final String type;
  final double? taxRate;
  const ReceiptItem({
    required this.id,
    required this.billId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.type,
    this.taxRate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bill_id'] = Variable<String>(billId);
    map['name'] = Variable<String>(name);
    map['quantity'] = Variable<int>(quantity);
    map['price'] = Variable<double>(price);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || taxRate != null) {
      map['tax_rate'] = Variable<double>(taxRate);
    }
    return map;
  }

  ReceiptItemsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptItemsCompanion(
      id: Value(id),
      billId: Value(billId),
      name: Value(name),
      quantity: Value(quantity),
      price: Value(price),
      type: Value(type),
      taxRate: taxRate == null && nullToAbsent
          ? const Value.absent()
          : Value(taxRate),
    );
  }

  factory ReceiptItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptItem(
      id: serializer.fromJson<String>(json['id']),
      billId: serializer.fromJson<String>(json['billId']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<int>(json['quantity']),
      price: serializer.fromJson<double>(json['price']),
      type: serializer.fromJson<String>(json['type']),
      taxRate: serializer.fromJson<double?>(json['taxRate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'billId': serializer.toJson<String>(billId),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<int>(quantity),
      'price': serializer.toJson<double>(price),
      'type': serializer.toJson<String>(type),
      'taxRate': serializer.toJson<double?>(taxRate),
    };
  }

  ReceiptItem copyWith({
    String? id,
    String? billId,
    String? name,
    int? quantity,
    double? price,
    String? type,
    Value<double?> taxRate = const Value.absent(),
  }) => ReceiptItem(
    id: id ?? this.id,
    billId: billId ?? this.billId,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    price: price ?? this.price,
    type: type ?? this.type,
    taxRate: taxRate.present ? taxRate.value : this.taxRate,
  );
  ReceiptItem copyWithCompanion(ReceiptItemsCompanion data) {
    return ReceiptItem(
      id: data.id.present ? data.id.value : this.id,
      billId: data.billId.present ? data.billId.value : this.billId,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      price: data.price.present ? data.price.value : this.price,
      type: data.type.present ? data.type.value : this.type,
      taxRate: data.taxRate.present ? data.taxRate.value : this.taxRate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptItem(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('type: $type, ')
          ..write('taxRate: $taxRate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, billId, name, quantity, price, type, taxRate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptItem &&
          other.id == this.id &&
          other.billId == this.billId &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.price == this.price &&
          other.type == this.type &&
          other.taxRate == this.taxRate);
}

class ReceiptItemsCompanion extends UpdateCompanion<ReceiptItem> {
  final Value<String> id;
  final Value<String> billId;
  final Value<String> name;
  final Value<int> quantity;
  final Value<double> price;
  final Value<String> type;
  final Value<double?> taxRate;
  final Value<int> rowid;
  const ReceiptItemsCompanion({
    this.id = const Value.absent(),
    this.billId = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.price = const Value.absent(),
    this.type = const Value.absent(),
    this.taxRate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptItemsCompanion.insert({
    required String id,
    required String billId,
    required String name,
    required int quantity,
    required double price,
    required String type,
    this.taxRate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       billId = Value(billId),
       name = Value(name),
       quantity = Value(quantity),
       price = Value(price),
       type = Value(type);
  static Insertable<ReceiptItem> custom({
    Expression<String>? id,
    Expression<String>? billId,
    Expression<String>? name,
    Expression<int>? quantity,
    Expression<double>? price,
    Expression<String>? type,
    Expression<double>? taxRate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (billId != null) 'bill_id': billId,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (price != null) 'price': price,
      if (type != null) 'type': type,
      if (taxRate != null) 'tax_rate': taxRate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? billId,
    Value<String>? name,
    Value<int>? quantity,
    Value<double>? price,
    Value<String>? type,
    Value<double?>? taxRate,
    Value<int>? rowid,
  }) {
    return ReceiptItemsCompanion(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      type: type ?? this.type,
      taxRate: taxRate ?? this.taxRate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (billId.present) {
      map['bill_id'] = Variable<String>(billId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (taxRate.present) {
      map['tax_rate'] = Variable<double>(taxRate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptItemsCompanion(')
          ..write('id: $id, ')
          ..write('billId: $billId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('price: $price, ')
          ..write('type: $type, ')
          ..write('taxRate: $taxRate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $GroupsTable groups = $GroupsTable(this);
  late final $BillsTable bills = $BillsTable(this);
  late final $ReceiptItemsTable receiptItems = $ReceiptItemsTable(this);
  late final UserDao userDao = UserDao(this as AppDatabase);
  late final GroupDao groupDao = GroupDao(this as AppDatabase);
  late final BillDao billDao = BillDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    groups,
    bills,
    receiptItems,
  ];
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      required String id,
      required String name,
      required String avatarInitials,
      Value<String?> profileImage,
      Value<String?> gradientColorValues,
      Value<bool> isGuest,
      Value<String?> phoneNumber,
      Value<int> rowid,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> avatarInitials,
      Value<String?> profileImage,
      Value<String?> gradientColorValues,
      Value<bool> isGuest,
      Value<String?> phoneNumber,
      Value<int> rowid,
    });

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarInitials => $composableBuilder(
    column: $table.avatarInitials,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileImage => $composableBuilder(
    column: $table.profileImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gradientColorValues => $composableBuilder(
    column: $table.gradientColorValues,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isGuest => $composableBuilder(
    column: $table.isGuest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarInitials => $composableBuilder(
    column: $table.avatarInitials,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileImage => $composableBuilder(
    column: $table.profileImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gradientColorValues => $composableBuilder(
    column: $table.gradientColorValues,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isGuest => $composableBuilder(
    column: $table.isGuest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatarInitials => $composableBuilder(
    column: $table.avatarInitials,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileImage => $composableBuilder(
    column: $table.profileImage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gradientColorValues => $composableBuilder(
    column: $table.gradientColorValues,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isGuest =>
      $composableBuilder(column: $table.isGuest, builder: (column) => column);

  GeneratedColumn<String> get phoneNumber => $composableBuilder(
    column: $table.phoneNumber,
    builder: (column) => column,
  );
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
          User,
          PrefetchHooks Function()
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> avatarInitials = const Value.absent(),
                Value<String?> profileImage = const Value.absent(),
                Value<String?> gradientColorValues = const Value.absent(),
                Value<bool> isGuest = const Value.absent(),
                Value<String?> phoneNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                name: name,
                avatarInitials: avatarInitials,
                profileImage: profileImage,
                gradientColorValues: gradientColorValues,
                isGuest: isGuest,
                phoneNumber: phoneNumber,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String avatarInitials,
                Value<String?> profileImage = const Value.absent(),
                Value<String?> gradientColorValues = const Value.absent(),
                Value<bool> isGuest = const Value.absent(),
                Value<String?> phoneNumber = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                name: name,
                avatarInitials: avatarInitials,
                profileImage: profileImage,
                gradientColorValues: gradientColorValues,
                isGuest: isGuest,
                phoneNumber: phoneNumber,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
      User,
      PrefetchHooks Function()
    >;
typedef $$GroupsTableCreateCompanionBuilder =
    GroupsCompanion Function({
      required String id,
      required String name,
      required String emoji,
      required int colorValue,
      Value<String?> createdBy,
      Value<String?> address,
      required String tenantIds,
      Value<String?> landlordId,
      Value<DateTime?> leaseStartDate,
      Value<DateTime?> leaseEndDate,
      Value<int> rowid,
    });
typedef $$GroupsTableUpdateCompanionBuilder =
    GroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> emoji,
      Value<int> colorValue,
      Value<String?> createdBy,
      Value<String?> address,
      Value<String> tenantIds,
      Value<String?> landlordId,
      Value<DateTime?> leaseStartDate,
      Value<DateTime?> leaseEndDate,
      Value<int> rowid,
    });

class $$GroupsTableFilterComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantIds => $composableBuilder(
    column: $table.tenantIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get landlordId => $composableBuilder(
    column: $table.landlordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get leaseStartDate => $composableBuilder(
    column: $table.leaseStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get leaseEndDate => $composableBuilder(
    column: $table.leaseEndDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantIds => $composableBuilder(
    column: $table.tenantIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get landlordId => $composableBuilder(
    column: $table.landlordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get leaseStartDate => $composableBuilder(
    column: $table.leaseStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get leaseEndDate => $composableBuilder(
    column: $table.leaseEndDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get tenantIds =>
      $composableBuilder(column: $table.tenantIds, builder: (column) => column);

  GeneratedColumn<String> get landlordId => $composableBuilder(
    column: $table.landlordId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get leaseStartDate => $composableBuilder(
    column: $table.leaseStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get leaseEndDate => $composableBuilder(
    column: $table.leaseEndDate,
    builder: (column) => column,
  );
}

class $$GroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupsTable,
          Group,
          $$GroupsTableFilterComposer,
          $$GroupsTableOrderingComposer,
          $$GroupsTableAnnotationComposer,
          $$GroupsTableCreateCompanionBuilder,
          $$GroupsTableUpdateCompanionBuilder,
          (Group, BaseReferences<_$AppDatabase, $GroupsTable, Group>),
          Group,
          PrefetchHooks Function()
        > {
  $$GroupsTableTableManager(_$AppDatabase db, $GroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String> tenantIds = const Value.absent(),
                Value<String?> landlordId = const Value.absent(),
                Value<DateTime?> leaseStartDate = const Value.absent(),
                Value<DateTime?> leaseEndDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion(
                id: id,
                name: name,
                emoji: emoji,
                colorValue: colorValue,
                createdBy: createdBy,
                address: address,
                tenantIds: tenantIds,
                landlordId: landlordId,
                leaseStartDate: leaseStartDate,
                leaseEndDate: leaseEndDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String emoji,
                required int colorValue,
                Value<String?> createdBy = const Value.absent(),
                Value<String?> address = const Value.absent(),
                required String tenantIds,
                Value<String?> landlordId = const Value.absent(),
                Value<DateTime?> leaseStartDate = const Value.absent(),
                Value<DateTime?> leaseEndDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion.insert(
                id: id,
                name: name,
                emoji: emoji,
                colorValue: colorValue,
                createdBy: createdBy,
                address: address,
                tenantIds: tenantIds,
                landlordId: landlordId,
                leaseStartDate: leaseStartDate,
                leaseEndDate: leaseEndDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupsTable,
      Group,
      $$GroupsTableFilterComposer,
      $$GroupsTableOrderingComposer,
      $$GroupsTableAnnotationComposer,
      $$GroupsTableCreateCompanionBuilder,
      $$GroupsTableUpdateCompanionBuilder,
      (Group, BaseReferences<_$AppDatabase, $GroupsTable, Group>),
      Group,
      PrefetchHooks Function()
    >;
typedef $$BillsTableCreateCompanionBuilder =
    BillsCompanion Function({
      required String id,
      required String title,
      required String location,
      required double totalAmount,
      required DateTime createdAt,
      required String participantIds,
      required String participantShares,
      required String paymentStatus,
      Value<String?> imageUrl,
      Value<String> category,
      Value<String> provider,
      Value<DateTime?> dueDate,
      Value<String> status,
      Value<int> rowid,
    });
typedef $$BillsTableUpdateCompanionBuilder =
    BillsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> location,
      Value<double> totalAmount,
      Value<DateTime> createdAt,
      Value<String> participantIds,
      Value<String> participantShares,
      Value<String> paymentStatus,
      Value<String?> imageUrl,
      Value<String> category,
      Value<String> provider,
      Value<DateTime?> dueDate,
      Value<String> status,
      Value<int> rowid,
    });

class $$BillsTableFilterComposer extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get participantIds => $composableBuilder(
    column: $table.participantIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get participantShares => $composableBuilder(
    column: $table.participantShares,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BillsTableOrderingComposer
    extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get participantIds => $composableBuilder(
    column: $table.participantIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get participantShares => $composableBuilder(
    column: $table.participantShares,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BillsTable> {
  $$BillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get participantIds => $composableBuilder(
    column: $table.participantIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get participantShares => $composableBuilder(
    column: $table.participantShares,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$BillsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BillsTable,
          Bill,
          $$BillsTableFilterComposer,
          $$BillsTableOrderingComposer,
          $$BillsTableAnnotationComposer,
          $$BillsTableCreateCompanionBuilder,
          $$BillsTableUpdateCompanionBuilder,
          (Bill, BaseReferences<_$AppDatabase, $BillsTable, Bill>),
          Bill,
          PrefetchHooks Function()
        > {
  $$BillsTableTableManager(_$AppDatabase db, $BillsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<double> totalAmount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> participantIds = const Value.absent(),
                Value<String> participantShares = const Value.absent(),
                Value<String> paymentStatus = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillsCompanion(
                id: id,
                title: title,
                location: location,
                totalAmount: totalAmount,
                createdAt: createdAt,
                participantIds: participantIds,
                participantShares: participantShares,
                paymentStatus: paymentStatus,
                imageUrl: imageUrl,
                category: category,
                provider: provider,
                dueDate: dueDate,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String location,
                required double totalAmount,
                required DateTime createdAt,
                required String participantIds,
                required String participantShares,
                required String paymentStatus,
                Value<String?> imageUrl = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillsCompanion.insert(
                id: id,
                title: title,
                location: location,
                totalAmount: totalAmount,
                createdAt: createdAt,
                participantIds: participantIds,
                participantShares: participantShares,
                paymentStatus: paymentStatus,
                imageUrl: imageUrl,
                category: category,
                provider: provider,
                dueDate: dueDate,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BillsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BillsTable,
      Bill,
      $$BillsTableFilterComposer,
      $$BillsTableOrderingComposer,
      $$BillsTableAnnotationComposer,
      $$BillsTableCreateCompanionBuilder,
      $$BillsTableUpdateCompanionBuilder,
      (Bill, BaseReferences<_$AppDatabase, $BillsTable, Bill>),
      Bill,
      PrefetchHooks Function()
    >;
typedef $$ReceiptItemsTableCreateCompanionBuilder =
    ReceiptItemsCompanion Function({
      required String id,
      required String billId,
      required String name,
      required int quantity,
      required double price,
      required String type,
      Value<double?> taxRate,
      Value<int> rowid,
    });
typedef $$ReceiptItemsTableUpdateCompanionBuilder =
    ReceiptItemsCompanion Function({
      Value<String> id,
      Value<String> billId,
      Value<String> name,
      Value<int> quantity,
      Value<double> price,
      Value<String> type,
      Value<double?> taxRate,
      Value<int> rowid,
    });

class $$ReceiptItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptItemsTable> {
  $$ReceiptItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billId => $composableBuilder(
    column: $table.billId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get taxRate => $composableBuilder(
    column: $table.taxRate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReceiptItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptItemsTable> {
  $$ReceiptItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billId => $composableBuilder(
    column: $table.billId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get taxRate => $composableBuilder(
    column: $table.taxRate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReceiptItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptItemsTable> {
  $$ReceiptItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get billId =>
      $composableBuilder(column: $table.billId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get taxRate =>
      $composableBuilder(column: $table.taxRate, builder: (column) => column);
}

class $$ReceiptItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReceiptItemsTable,
          ReceiptItem,
          $$ReceiptItemsTableFilterComposer,
          $$ReceiptItemsTableOrderingComposer,
          $$ReceiptItemsTableAnnotationComposer,
          $$ReceiptItemsTableCreateCompanionBuilder,
          $$ReceiptItemsTableUpdateCompanionBuilder,
          (
            ReceiptItem,
            BaseReferences<_$AppDatabase, $ReceiptItemsTable, ReceiptItem>,
          ),
          ReceiptItem,
          PrefetchHooks Function()
        > {
  $$ReceiptItemsTableTableManager(_$AppDatabase db, $ReceiptItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> billId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<double> price = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double?> taxRate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptItemsCompanion(
                id: id,
                billId: billId,
                name: name,
                quantity: quantity,
                price: price,
                type: type,
                taxRate: taxRate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String billId,
                required String name,
                required int quantity,
                required double price,
                required String type,
                Value<double?> taxRate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptItemsCompanion.insert(
                id: id,
                billId: billId,
                name: name,
                quantity: quantity,
                price: price,
                type: type,
                taxRate: taxRate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReceiptItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReceiptItemsTable,
      ReceiptItem,
      $$ReceiptItemsTableFilterComposer,
      $$ReceiptItemsTableOrderingComposer,
      $$ReceiptItemsTableAnnotationComposer,
      $$ReceiptItemsTableCreateCompanionBuilder,
      $$ReceiptItemsTableUpdateCompanionBuilder,
      (
        ReceiptItem,
        BaseReferences<_$AppDatabase, $ReceiptItemsTable, ReceiptItem>,
      ),
      ReceiptItem,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db, _db.groups);
  $$BillsTableTableManager get bills =>
      $$BillsTableTableManager(_db, _db.bills);
  $$ReceiptItemsTableTableManager get receiptItems =>
      $$ReceiptItemsTableTableManager(_db, _db.receiptItems);
}
