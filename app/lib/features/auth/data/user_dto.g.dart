// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserDto _$UserDtoFromJson(Map<String, dynamic> json) => UserDto(
  id: json['id'] as String,
  email: json['email'] as String,
  displayName: json['display_name'] as String,
  timezone: json['timezone'] as String,
  dayStartTime: json['day_start_time'] as String,
  isOnboarded: json['is_onboarded'] as bool,
);

Map<String, dynamic> _$UserDtoToJson(UserDto instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'display_name': instance.displayName,
  'timezone': instance.timezone,
  'day_start_time': instance.dayStartTime,
  'is_onboarded': instance.isOnboarded,
};
