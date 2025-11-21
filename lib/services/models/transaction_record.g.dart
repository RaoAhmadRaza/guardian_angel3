// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionRecordAdapter extends TypeAdapter<TransactionRecord> {
  @override
  final int typeId = 30;

  @override
  TransactionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionRecord(
      transactionId: fields[0] as String,
      createdAt: fields[1] as DateTime,
      state: fields[2] as TransactionState,
      committedAt: fields[3] as DateTime?,
      appliedAt: fields[4] as DateTime?,
      modelChanges: (fields[5] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as Map).cast<String, dynamic>())),
      pendingOp: (fields[6] as Map?)?.cast<String, dynamic>(),
      indexEntries: (fields[7] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as List).cast<String>())),
      errorMessage: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.transactionId)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.state)
      ..writeByte(3)
      ..write(obj.committedAt)
      ..writeByte(4)
      ..write(obj.appliedAt)
      ..writeByte(5)
      ..write(obj.modelChanges)
      ..writeByte(6)
      ..write(obj.pendingOp)
      ..writeByte(7)
      ..write(obj.indexEntries)
      ..writeByte(8)
      ..write(obj.errorMessage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
