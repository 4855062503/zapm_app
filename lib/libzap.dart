import 'dart:ffi';
import 'dart:typed_data';
import "dart:convert";
import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';

import 'dylib_utils.dart';
import 'utf8.dart';
import 'bytes.dart';

class IntResult {
  bool success;
  int value;
  IntResult(this.success, this.value);
}

class Tx {
  static final textFieldSize = 1024;
  static final int64FieldSize = 8;
  static final totalSize = int64FieldSize + textFieldSize * 6 + int64FieldSize * 3;

  int type;
  String id;
  String sender;
  String recipient;
  String assetId;
  String feeAsset;
  String attachment;
  int amount;
  int fee;
  int timestamp;

  Tx(this.type, this.id, this.sender, this.recipient, this.assetId, this.feeAsset, this.attachment, this.amount, this.fee, this.timestamp);

  Pointer<CBuffer> toBuffer() {
    var buf = CBuffer.allocate(totalSize);
    var offset = 0;

    // type field
    var intList = new Uint8List(int64FieldSize);
    var intByteData = new ByteData.view(intList.buffer);
    intByteData.setInt64(offset, type);
    offset += int64FieldSize;
    // id field
    buf.load().copyInto(offset, utf8.encode(id));
    offset += textFieldSize;
    // sender field
    buf.load().copyInto(offset, utf8.encode(sender));
    offset += textFieldSize;
    // recipient field
    buf.load().copyInto(offset, utf8.encode(recipient));
    offset += textFieldSize;
    // assetId field
    buf.load().copyInto(offset, utf8.encode(assetId));
    offset += textFieldSize;
    // feeAsset field
    buf.load().copyInto(offset, utf8.encode(feeAsset));
    offset += textFieldSize;
    // attachment field
    buf.load().copyInto(offset, utf8.encode(attachment));
    offset += textFieldSize;
    // amount field
    intByteData.setInt64(0, amount);
    buf.load().copyInto(offset, intList);
    offset += int64FieldSize;
    // amount field
    intByteData.setInt64(0, fee);
    buf.load().copyInto(offset, intList);
    offset += int64FieldSize;
    // amount field
    intByteData.setInt64(0, timestamp);
    buf.load().copyInto(offset, intList);
    offset += int64FieldSize;

    return buf;
  }

  static Tx fromCBuffer(CBuffer buf) {
    var ints = buf.toIntList(totalSize);
    int offset = 0;

    var type = Int8List.fromList(ints).buffer.asByteData().getInt64(offset, Endian.little);
    offset += 8;
    var id = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var sender = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var recipient = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var assetId = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var feeAsset = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var attachment = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var amount = Int8List.fromList(ints).buffer.asByteData().getInt64(offset, Endian.little);
    offset += 8;
    var fee = Int8List.fromList(ints).buffer.asByteData().getInt64(offset, Endian.little);
    offset += 8;
    var timestamp = Int8List.fromList(ints).buffer.asByteData().getInt64(offset, Endian.little);
    offset += 8;

    return Tx(type, id, sender, recipient, assetId, feeAsset, attachment, amount, fee, timestamp);
  }

  static Pointer<CBuffer> allocate() {
    return Pointer.allocate(count: totalSize);
  }
}

class SpendTx {
  static final successFieldSize = 1;
  static final dataFieldSize = 364;
  static final dataSizeFieldSize = 4;
  static final sigFieldSize = 64;
  static final totalSize = successFieldSize + dataFieldSize + dataSizeFieldSize + sigFieldSize;

  bool success;
  Iterable<int> data;
  Iterable<int> signature;

  SpendTx(this.success, this.data, this.signature);

  Pointer<CBuffer> toBuffer() {
    var buf = CBuffer.allocate(totalSize);

    // success field
    buf.elementAt(0).load<CBuffer>().byte = success ? 1 : 0;
    // data field
    buf.load().copyInto(successFieldSize, data);
    // data_size field
    var dataSizeList = new Uint8List(dataSizeFieldSize);
    var dataSizeByteData = new ByteData.view(dataSizeList.buffer);
    dataSizeByteData.setInt32(0, data.length);
    buf.load().copyInto(successFieldSize + dataFieldSize, dataSizeList);
    // signature field
    buf.load().copyInto(successFieldSize + dataFieldSize + dataSizeFieldSize, signature);

    return buf;
  }

  static SpendTx fromCBuffer(CBuffer buf) {
    var ints = buf.toIntList(totalSize);

    var success = ints[0] != 0;
    var dataSize = Int8List.fromList(ints).buffer.asByteData().getInt32(successFieldSize + dataFieldSize, Endian.big);
    assert(dataSize >= 0 && dataSize <= dataFieldSize);
    var data = ints.skip(successFieldSize).take(dataSize);
    var sig = ints.skip(successFieldSize + dataFieldSize + dataSizeFieldSize).take(sigFieldSize);

    return SpendTx(success, data, sig);
  }

  static Pointer<CBuffer> allocate() {
    return Pointer.allocate(count: totalSize);
  }
}

//
// native libzap definitions
//

class IntResultNative extends Struct<IntResultNative> {
  @Int8()
  int success;

  @Int64()
  int value;

  factory IntResultNative.allocate(bool success, int value) {
    return Pointer<IntResultNative>.allocate().load<IntResultNative>()
      ..success = (success ? 1 : 0)
      ..value = value;
  }
}

/* c def
#define MAX_TXFIELD 1024
struct waves_payment_request_t
{
  char address[MAX_TXFIELD];
  char asset_id[MAX_TXFIELD];
  char attachment[MAX_TXFIELD];
  uint64_t amount;
};
*/
class WavesPaymentRequest extends Struct<WavesPaymentRequest> {
  //TODO
}

typedef lzap_version_native_t = Int32 Function();
typedef lzap_version_t = int Function();

typedef lzap_network_get_native_t = Int8 Function();
typedef lzap_network_get_t = int Function();
typedef lzap_network_set_native_t = Int32 Function(Int8 network_byte);
typedef lzap_network_set_t = int Function(int network_byte);

typedef lzap_mnemonic_create_native_t = Int32 Function(Pointer<Utf8> output, Int32 size);
typedef lzap_mnemonic_create_t = int Function(Pointer<Utf8> output, int size);

//TODO: this function does not actually return anything, but dart:ffi does not seem to handle void functions yet
typedef lzap_seed_address_native_t = Int32 Function(Pointer<Utf8> seed, Pointer<Utf8> output);
typedef lzap_seed_address_t = int Function(Pointer<Utf8> seed, Pointer<Utf8> output);

typedef lzap_address_check_native_t = IntResult Function(Pointer<Utf8> address);
typedef lzap_address_check_ns_native_t = Int8 Function(Pointer<Utf8> address);
typedef lzap_address_check_ns_t = int Function(Pointer<Utf8> address);

typedef lzap_address_balance_ns_native_t = Int8 Function(Pointer<Utf8> address, Pointer<Int64> balance_out);
typedef lzap_address_balance_ns_t = int Function(Pointer<Utf8> address, Pointer<Int64> balance_out);

//TODO: this function does not actually return anything, but dart:ffi does not seem to handle void functions yet
typedef lzap_transaction_create_ns_native_t = Int32 Function(Pointer<Utf8> seed, Pointer<Utf8> recipient, Int64 amount, Int64 fee, Pointer<Utf8> attachment, Pointer<CBuffer> spend_tx_out);
typedef lzap_transaction_create_ns_t = int Function(Pointer<Utf8> seed, Pointer<Utf8> recipient, int amount, int fee, Pointer<Utf8> attachment, Pointer<CBuffer> spend_tx_out);

//TODO: ns version of transaction broadcast!!!
typedef lzap_transaction_broadcast_ns_native_t = Int32 Function(Pointer<CBuffer> spend_tx, Pointer<CBuffer> broadcast_tx_out);
typedef lzap_transaction_broadcast_ns_t = int Function(Pointer<CBuffer> spend_tx, Pointer<CBuffer> broadcast_tx_out);

//
// helper functions
//

String intListToString(Iterable<int> lst, int offset, int count) {
  lst = lst.skip(offset).take(count);
  int len = 0;
  while (lst.elementAt(len) != 0)
    len++;
  return Utf8Decoder().convert(lst.take(len).toList());
}

IntResult addressBalanceFromIsolate(String address) {
  // as we are running this in an isolate we need to reinit a LibZap instance
  // to get the function pointer as closures can not be passed to isolates
  var libzap = LibZap();

  var addrC = Utf8.allocate(address);
  var balanceP = Pointer<Int64>.allocate();
  var res = libzap.lzap_address_balance(addrC, balanceP) != 0;
  int balance = balanceP.load();
  balanceP.free();
  addrC.free();
  return IntResult(res != 0, balance);
}

//
// LibZap class
//

class LibZap {

  LibZap() {
    libzap = dlopenPlatformSpecific("zap");
    lzap_version = libzap
        .lookup<NativeFunction<lzap_version_native_t>>("lzap_version")
        .asFunction();
    lzap_network_get = libzap
        .lookup<NativeFunction<lzap_network_get_native_t>>("lzap_network_get")
        .asFunction();
    lzap_network_set = libzap
        .lookup<NativeFunction<lzap_network_set_native_t>>("lzap_network_set")
        .asFunction();
    lzap_version = libzap
        .lookup<NativeFunction<lzap_version_native_t>>("lzap_version")
        .asFunction();
    lzap_mnemonic_create = libzap
        .lookup<NativeFunction<lzap_mnemonic_create_native_t>>("lzap_mnemonic_create")
        .asFunction();
    lzap_seed_address = libzap
        .lookup<NativeFunction<lzap_seed_address_native_t>>("lzap_seed_address")
        .asFunction();
    lzap_address_check = libzap
        .lookup<NativeFunction<lzap_address_check_ns_native_t>>("lzap_address_check_ns")
        .asFunction();
    lzap_address_balance = libzap
        .lookup<NativeFunction<lzap_address_balance_ns_native_t>>("lzap_address_balance_ns")
        .asFunction();
    lzap_transaction_create = libzap
        .lookup<NativeFunction<lzap_transaction_create_ns_native_t>>("lzap_transaction_create_ns")
        .asFunction();
    lzap_transaction_broadcast = libzap
        .lookup<NativeFunction<lzap_transaction_broadcast_ns_native_t>>("lzap_transaction_broadcast_ns")
        .asFunction();
  }

  static const String ASSET_ID = "CgUrFtinLXEbJwJVjwwcppk4Vpz1nMmR3H5cQaDcUcfe";

  DynamicLibrary libzap;
  lzap_version_t lzap_version;
  lzap_network_get_t lzap_network_get;
  lzap_network_set_t lzap_network_set;
  lzap_mnemonic_create_t lzap_mnemonic_create;
  lzap_seed_address_t lzap_seed_address;
  lzap_address_check_ns_t lzap_address_check;
  lzap_address_balance_ns_t lzap_address_balance;
  lzap_transaction_create_ns_t lzap_transaction_create;
  lzap_transaction_broadcast_ns_t lzap_transaction_broadcast;

  static String paymentUri(String address, int amount) {
    var uri = "waves://$address?asset=$ASSET_ID";
    if (amount != null)
      uri += "&amount=$amount";
    return uri;
  }

  static String paymentUriDec(String address, Decimal amount) {
    if (amount != null && amount > Decimal.fromInt(0)) {
      amount = amount * Decimal.fromInt(100);
      var amountInt = amount.toInt();
      return paymentUri(address, amountInt);
    }
    return paymentUri(address, null);
  }

  //
  // native libzap wrapper functions
  //

  int version() {
    return lzap_version();
  }

  bool testnetGet() {
    var networkByte = String.fromCharCode(lzap_network_get());
    if (networkByte == 'T')
      return true;
    else if (networkByte == 'W')
      return false;
    else
      throw new FormatException("network byte not recognised");
  }

  bool testnetSet(bool value) {
    String networkByte;
    if (value)
      networkByte = 'T';
    else
      networkByte = 'W';
    int char = networkByte.codeUnitAt(0);
    return lzap_network_set(char) != 0;
  }

  String mnemonicCreate() {
    var mem = "0" * 1024;
    var outputC = Utf8.allocate(mem);
    var res = lzap_mnemonic_create(outputC, 1024);
    var mnemonic = outputC.load().toString();
    outputC.free();
    if (res != 0)
      return mnemonic;
    return null;
  }

  String seedAddress(String seed) {
    var seedC = Utf8.allocate(seed);
    var mem = "0" * 1024;
    var outputC = Utf8.allocate(mem);
    lzap_seed_address(seedC, outputC);
    var address = outputC.load().toString();
    outputC.free();
    seedC.free();
    return address;
  }

  bool addressCheck(String address) {
    var addrC = Utf8.allocate(address);
    var res = lzap_address_check(addrC) != 0;
    addrC.free();
    return res;
  }

  Future<IntResult> addrBalance(String address) async {
    return compute(addressBalanceFromIsolate, address);
  }

  SpendTx transactionCreate(String seed, String recipient, int amount, int fee, String attachment) {
    var seedC = Utf8.allocate(seed);
    var recipientC = Utf8.allocate(recipient);
    Pointer<Utf8> attachmentC = Utf8.allocate("");
    if (attachment != null)
      attachmentC = Utf8.allocate(attachment);
    var outputC = SpendTx.allocate();
    lzap_transaction_create(seedC, recipientC, amount, fee, attachmentC, outputC);
    var spendTx = SpendTx.fromCBuffer(outputC.load());
    outputC.free();
    attachmentC.free();
    recipientC.free();
    seedC.free();
    return spendTx;
  }

  Tx transactionBroadcast(SpendTx spendTx) {
    var spendTxC = spendTx.toBuffer();
    var txC = Tx.allocate();
    var result = lzap_transaction_broadcast(spendTxC, txC);
    Tx tx = null;
    if (result != 0)
     tx = Tx.fromCBuffer(txC.load());
    txC.free();
    spendTxC.free();
    return tx;
  }
}