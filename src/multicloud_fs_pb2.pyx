# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# NO CHECKED-IN PROTOBUF GENCODE
# source: multicloud_fs.proto
# Protobuf Python Version: 5.29.0
"""Generated protocol buffer code."""
from google.protobuf import descriptor as _descriptor
from google.protobuf import descriptor_pool as _descriptor_pool
from google.protobuf import runtime_version as _runtime_version
from google.protobuf import symbol_database as _symbol_database
from google.protobuf.internal import builder as _builder

_runtime_version.ValidateProtobufRuntimeVersion(
    _runtime_version.Domain.PUBLIC, 5, 29, 0, "", "multicloud_fs.proto"
)
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()


DESCRIPTOR = _descriptor_pool.Default().AddSerializedFile(
    b'\n\x13multicloud_fs.proto\x12\x0emulti_cloud_fs"\x1d\n\rExistsRequest\x12\x0c\n\x04path\x18\x01 \x01(\t" \n\x0e\x45xistsResponse\x12\x0e\n\x06\x65xists\x18\x01 \x01(\x08"\x1e\n\x0eGetAttrRequest\x12\x0c\n\x04path\x18\x01 \x01(\t"\xbb\x01\n\x0fGetAttrResponse\x12\x0f\n\x07st_mode\x18\x01 \x01(\x03\x12\x0e\n\x06st_ino\x18\x02 \x01(\x03\x12\x0e\n\x06st_dev\x18\x03 \x01(\x03\x12\x10\n\x08st_nlink\x18\x04 \x01(\x03\x12\x0e\n\x06st_uid\x18\x05 \x01(\x03\x12\x0e\n\x06st_gid\x18\x06 \x01(\x03\x12\x0f\n\x07st_size\x18\x07 \x01(\x03\x12\x10\n\x08st_atime\x18\x08 \x01(\x02\x12\x10\n\x08st_mtime\x18\t \x01(\x02\x12\x10\n\x08st_ctime\x18\n \x01(\x02".\n\x0eReadDirRequest\x12\x0c\n\x04path\x18\x01 \x01(\t\x12\x0e\n\x06offset\x18\x02 \x01(\x03""\n\x0fReadDirResponse\x12\x0f\n\x07\x65ntries\x18\x01 \x03(\t"9\n\x0bReadRequest\x12\x0c\n\x04path\x18\x01 \x01(\t\x12\x0e\n\x06offset\x18\x02 \x01(\x03\x12\x0c\n\x04size\x18\x03 \x01(\x03"\x1c\n\x0cReadResponse\x12\x0c\n\x04\x64\x61ta\x18\x01 \x01(\x0c":\n\x0cWriteRequest\x12\x0c\n\x04path\x18\x01 \x01(\t\x12\x0c\n\x04\x64\x61ta\x18\x02 \x01(\x0c\x12\x0e\n\x06offset\x18\x03 \x01(\x03"&\n\rWriteResponse\x12\x15\n\rbytes_written\x18\x01 \x01(\x03"-\n\x0fTruncateRequest\x12\x0c\n\x04path\x18\x01 \x01(\t\x12\x0c\n\x04size\x18\x02 \x01(\x03"#\n\x10TruncateResponse\x12\x0f\n\x07success\x18\x01 \x01(\x08"6\n\x0c\x43hownRequest\x12\x0c\n\x04path\x18\x01 \x01(\t\x12\x0b\n\x03uid\x18\x02 \x01(\x03\x12\x0b\n\x03gid\x18\x03 \x01(\x03" \n\rChownResponse\x12\x0f\n\x07success\x18\x01 \x01(\x08"*\n\x0c\x43hmodRequest\x12\x0c\n\x04path\x18\x01 \x01(\t\x12\x0c\n\x04mode\x18\x02 \x01(\x03" \n\rChmodResponse\x12\x0f\n\x07success\x18\x01 \x01(\x08"\x1d\n\rUnlinkRequest\x12\x0c\n\x04path\x18\x01 \x01(\t"!\n\x0eUnlinkResponse\x12\x0f\n\x07success\x18\x01 \x01(\x08"\x1c\n\x0cRmdirRequest\x12\x0c\n\x04path\x18\x01 \x01(\t" \n\rRmdirResponse\x12\x0f\n\x07success\x18\x01 \x01(\x08"3\n\rRenameRequest\x12\x10\n\x08old_path\x18\x01 \x01(\t\x12\x10\n\x08new_path\x18\x02 \x01(\t"!\n\x0eRenameResponse\x12\x0f\n\x07success\x18\x01 \x01(\x08"+\n\rAccessRequest\x12\x0c\n\x04path\x18\x01 \x01(\t\x12\x0c\n\x04mode\x18\x02 \x01(\x05"!\n\x0e\x41\x63\x63\x65ssResponse\x12\x0f\n\x07success\x18\x01 \x01(\x08"\x7f\n\x0eUtimensRequest\x12\x0c\n\x04path\x18\x01 \x01(\t\x12\x11\n\thas_times\x18\x02 \x01(\x08\x12\x11\n\tatime_sec\x18\x03 \x01(\x03\x12\x12\n\natime_nsec\x18\x04 \x01(\x03\x12\x11\n\tmtime_sec\x18\x05 \x01(\x03\x12\x12\n\nmtime_nsec\x18\x06 \x01(\x03""\n\x0fUtimensResponse\x12\x0f\n\x07success\x18\x01 \x01(\x08"*\n\x0cMkdirRequest\x12\x0c\n\x04path\x18\x01 \x01(\t\x12\x0c\n\x04mode\x18\x02 \x01(\x03" \n\rMkdirResponse\x12\x0f\n\x07success\x18\x01 \x01(\x08":\n\rCreateRequest\x12\x0c\n\x04path\x18\x01 \x01(\t\x12\r\n\x05\x66lags\x18\x02 \x01(\x03\x12\x0c\n\x04mode\x18\x03 \x01(\x03"!\n\x0e\x43reateResponse\x12\x0f\n\x07success\x18\x01 \x01(\x08\x32\xeb\x08\n\nOperations\x12I\n\x06\x45xists\x12\x1d.multi_cloud_fs.ExistsRequest\x1a\x1e.multi_cloud_fs.ExistsResponse"\x00\x12L\n\x07GetAttr\x12\x1e.multi_cloud_fs.GetAttrRequest\x1a\x1f.multi_cloud_fs.GetAttrResponse"\x00\x12L\n\x07ReadDir\x12\x1e.multi_cloud_fs.ReadDirRequest\x1a\x1f.multi_cloud_fs.ReadDirResponse"\x00\x12\x43\n\x04Read\x12\x1b.multi_cloud_fs.ReadRequest\x1a\x1c.multi_cloud_fs.ReadResponse"\x00\x12\x46\n\x05Write\x12\x1c.multi_cloud_fs.WriteRequest\x1a\x1d.multi_cloud_fs.WriteResponse"\x00\x12O\n\x08Truncate\x12\x1f.multi_cloud_fs.TruncateRequest\x1a .multi_cloud_fs.TruncateResponse"\x00\x12\x46\n\x05\x43hown\x12\x1c.multi_cloud_fs.ChownRequest\x1a\x1d.multi_cloud_fs.ChownResponse"\x00\x12\x46\n\x05\x43hmod\x12\x1c.multi_cloud_fs.ChmodRequest\x1a\x1d.multi_cloud_fs.ChmodResponse"\x00\x12I\n\x06Unlink\x12\x1d.multi_cloud_fs.UnlinkRequest\x1a\x1e.multi_cloud_fs.UnlinkResponse"\x00\x12\x46\n\x05Rmdir\x12\x1c.multi_cloud_fs.RmdirRequest\x1a\x1d.multi_cloud_fs.RmdirResponse"\x00\x12I\n\x06Rename\x12\x1d.multi_cloud_fs.RenameRequest\x1a\x1e.multi_cloud_fs.RenameResponse"\x00\x12I\n\x06\x41\x63\x63\x65ss\x12\x1d.multi_cloud_fs.AccessRequest\x1a\x1e.multi_cloud_fs.AccessResponse"\x00\x12L\n\x07Utimens\x12\x1e.multi_cloud_fs.UtimensRequest\x1a\x1f.multi_cloud_fs.UtimensResponse"\x00\x12\x46\n\x05Mkdir\x12\x1c.multi_cloud_fs.MkdirRequest\x1a\x1d.multi_cloud_fs.MkdirResponse"\x00\x12I\n\x06\x43reate\x12\x1d.multi_cloud_fs.CreateRequest\x1a\x1e.multi_cloud_fs.CreateResponse"\x00\x62\x06proto3'
)

_globals = globals()
_builder.BuildMessageAndEnumDescriptors(DESCRIPTOR, _globals)
_builder.BuildTopDescriptorsAndMessages(DESCRIPTOR, "multicloud_fs_pb2", _globals)
if not _descriptor._USE_C_DESCRIPTORS:
    DESCRIPTOR._loaded_options = None
    _globals["_EXISTSREQUEST"]._serialized_start = 39
    _globals["_EXISTSREQUEST"]._serialized_end = 68
    _globals["_EXISTSRESPONSE"]._serialized_start = 70
    _globals["_EXISTSRESPONSE"]._serialized_end = 102
    _globals["_GETATTRREQUEST"]._serialized_start = 104
    _globals["_GETATTRREQUEST"]._serialized_end = 134
    _globals["_GETATTRRESPONSE"]._serialized_start = 137
    _globals["_GETATTRRESPONSE"]._serialized_end = 324
    _globals["_READDIRREQUEST"]._serialized_start = 326
    _globals["_READDIRREQUEST"]._serialized_end = 372
    _globals["_READDIRRESPONSE"]._serialized_start = 374
    _globals["_READDIRRESPONSE"]._serialized_end = 408
    _globals["_READREQUEST"]._serialized_start = 410
    _globals["_READREQUEST"]._serialized_end = 467
    _globals["_READRESPONSE"]._serialized_start = 469
    _globals["_READRESPONSE"]._serialized_end = 497
    _globals["_WRITEREQUEST"]._serialized_start = 499
    _globals["_WRITEREQUEST"]._serialized_end = 557
    _globals["_WRITERESPONSE"]._serialized_start = 559
    _globals["_WRITERESPONSE"]._serialized_end = 597
    _globals["_TRUNCATEREQUEST"]._serialized_start = 599
    _globals["_TRUNCATEREQUEST"]._serialized_end = 644
    _globals["_TRUNCATERESPONSE"]._serialized_start = 646
    _globals["_TRUNCATERESPONSE"]._serialized_end = 681
    _globals["_CHOWNREQUEST"]._serialized_start = 683
    _globals["_CHOWNREQUEST"]._serialized_end = 737
    _globals["_CHOWNRESPONSE"]._serialized_start = 739
    _globals["_CHOWNRESPONSE"]._serialized_end = 771
    _globals["_CHMODREQUEST"]._serialized_start = 773
    _globals["_CHMODREQUEST"]._serialized_end = 815
    _globals["_CHMODRESPONSE"]._serialized_start = 817
    _globals["_CHMODRESPONSE"]._serialized_end = 849
    _globals["_UNLINKREQUEST"]._serialized_start = 851
    _globals["_UNLINKREQUEST"]._serialized_end = 880
    _globals["_UNLINKRESPONSE"]._serialized_start = 882
    _globals["_UNLINKRESPONSE"]._serialized_end = 915
    _globals["_RMDIRREQUEST"]._serialized_start = 917
    _globals["_RMDIRREQUEST"]._serialized_end = 945
    _globals["_RMDIRRESPONSE"]._serialized_start = 947
    _globals["_RMDIRRESPONSE"]._serialized_end = 979
    _globals["_RENAMEREQUEST"]._serialized_start = 981
    _globals["_RENAMEREQUEST"]._serialized_end = 1032
    _globals["_RENAMERESPONSE"]._serialized_start = 1034
    _globals["_RENAMERESPONSE"]._serialized_end = 1067
    _globals["_ACCESSREQUEST"]._serialized_start = 1069
    _globals["_ACCESSREQUEST"]._serialized_end = 1112
    _globals["_ACCESSRESPONSE"]._serialized_start = 1114
    _globals["_ACCESSRESPONSE"]._serialized_end = 1147
    _globals["_UTIMENSREQUEST"]._serialized_start = 1149
    _globals["_UTIMENSREQUEST"]._serialized_end = 1276
    _globals["_UTIMENSRESPONSE"]._serialized_start = 1278
    _globals["_UTIMENSRESPONSE"]._serialized_end = 1312
    _globals["_MKDIRREQUEST"]._serialized_start = 1314
    _globals["_MKDIRREQUEST"]._serialized_end = 1356
    _globals["_MKDIRRESPONSE"]._serialized_start = 1358
    _globals["_MKDIRRESPONSE"]._serialized_end = 1390
    _globals["_CREATEREQUEST"]._serialized_start = 1392
    _globals["_CREATEREQUEST"]._serialized_end = 1450
    _globals["_CREATERESPONSE"]._serialized_start = 1452
    _globals["_CREATERESPONSE"]._serialized_end = 1485
    _globals["_OPERATIONS"]._serialized_start = 1488
    _globals["_OPERATIONS"]._serialized_end = 2619
# @@protoc_insertion_point(module_scope)
