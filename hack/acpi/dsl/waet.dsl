/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20190509 (64-bit version)
 * Copyright (c) 2000 - 2019 Intel Corporation
 * 
 * Disassembly of waet.dat, Mon May 24 15:35:46 2021
 *
 * ACPI Data Table [WAET]
 *
 * Format: [HexOffset DecimalOffset ByteLength]  FieldName : FieldValue
 */

[000h 0000   4]                    Signature : "WAET"    [Windows ACPI Emulated Devices Table]
[004h 0004   4]                 Table Length : 00000028
[008h 0008   1]                     Revision : 01
[009h 0009   1]                     Checksum : 39
[00Ah 0010   6]                       Oem ID : "BOCHS "
[010h 0016   8]                 Oem Table ID : "BXPC    "
[018h 0024   4]                 Oem Revision : 00000001
[01Ch 0028   4]              Asl Compiler ID : "BXPC"
[020h 0032   4]        Asl Compiler Revision : 00000001

[024h 0036   4]        Flags (decoded below) : 00000002
                        RTC needs no INT ack : 0
                     PM timer, one read only : 1

Raw Table Data: Length 40 (0x28)

    0000: 57 41 45 54 28 00 00 00 01 39 42 4F 43 48 53 20  // WAET(....9BOCHS 
    0010: 42 58 50 43 20 20 20 20 01 00 00 00 42 58 50 43  // BXPC    ....BXPC
    0020: 01 00 00 00 02 00 00 00                          // ........
