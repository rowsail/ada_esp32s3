pragma Style_Checks (Off);

--  Copyright 2024 Espressif Systems (Shanghai) PTE LTD
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

--  This spec has been automatically generated from esp32s3.svd

pragma Restrictions (No_Elaboration_Code);

with System;

package ESP32S3_Registers.USB is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   type GOTGCTL_Register is record
      --  Read-only.
      SESREQSCS       : Boolean := False;
      SESREQ          : Boolean := False;
      VBVALIDOVEN     : Boolean := False;
      VBVALIDOVVAL    : Boolean := False;
      AVALIDOVEN      : Boolean := False;
      AVALIDOVVAL     : Boolean := False;
      BVALIDOVEN      : Boolean := False;
      BVALIDOVVAL     : Boolean := False;
      --  Read-only.
      HSTNEGSCS       : Boolean := False;
      HNPREQ          : Boolean := False;
      HSTSETHNPEN     : Boolean := False;
      DEVHNPEN        : Boolean := False;
      EHEN            : Boolean := False;
      --  unspecified
      Reserved_13_14  : ESP32S3_Registers.UInt2 := 16#0#;
      DBNCEFLTRBYPASS : Boolean := False;
      --  Read-only.
      CONIDSTS        : Boolean := False;
      --  Read-only.
      DBNCTIME        : Boolean := False;
      --  Read-only.
      ASESVLD         : Boolean := False;
      --  Read-only.
      BSESVLD         : Boolean := False;
      OTGVER          : Boolean := False;
      --  Read-only.
      CURMOD          : Boolean := False;
      --  unspecified
      Reserved_22_31  : ESP32S3_Registers.UInt10 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GOTGCTL_Register use record
      SESREQSCS       at 0 range 0 .. 0;
      SESREQ          at 0 range 1 .. 1;
      VBVALIDOVEN     at 0 range 2 .. 2;
      VBVALIDOVVAL    at 0 range 3 .. 3;
      AVALIDOVEN      at 0 range 4 .. 4;
      AVALIDOVVAL     at 0 range 5 .. 5;
      BVALIDOVEN      at 0 range 6 .. 6;
      BVALIDOVVAL     at 0 range 7 .. 7;
      HSTNEGSCS       at 0 range 8 .. 8;
      HNPREQ          at 0 range 9 .. 9;
      HSTSETHNPEN     at 0 range 10 .. 10;
      DEVHNPEN        at 0 range 11 .. 11;
      EHEN            at 0 range 12 .. 12;
      Reserved_13_14  at 0 range 13 .. 14;
      DBNCEFLTRBYPASS at 0 range 15 .. 15;
      CONIDSTS        at 0 range 16 .. 16;
      DBNCTIME        at 0 range 17 .. 17;
      ASESVLD         at 0 range 18 .. 18;
      BSESVLD         at 0 range 19 .. 19;
      OTGVER          at 0 range 20 .. 20;
      CURMOD          at 0 range 21 .. 21;
      Reserved_22_31  at 0 range 22 .. 31;
   end record;

   type GOTGINT_Register is record
      --  unspecified
      Reserved_0_1     : ESP32S3_Registers.UInt2 := 16#0#;
      SESENDDET        : Boolean := False;
      --  unspecified
      Reserved_3_7     : ESP32S3_Registers.UInt5 := 16#0#;
      SESREQSUCSTSCHNG : Boolean := False;
      HSTNEGSUCSTSCHNG : Boolean := False;
      --  unspecified
      Reserved_10_16   : ESP32S3_Registers.UInt7 := 16#0#;
      HSTNEGDET        : Boolean := False;
      ADEVTOUTCHG      : Boolean := False;
      DBNCEDONE        : Boolean := False;
      --  unspecified
      Reserved_20_31   : ESP32S3_Registers.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GOTGINT_Register use record
      Reserved_0_1     at 0 range 0 .. 1;
      SESENDDET        at 0 range 2 .. 2;
      Reserved_3_7     at 0 range 3 .. 7;
      SESREQSUCSTSCHNG at 0 range 8 .. 8;
      HSTNEGSUCSTSCHNG at 0 range 9 .. 9;
      Reserved_10_16   at 0 range 10 .. 16;
      HSTNEGDET        at 0 range 17 .. 17;
      ADEVTOUTCHG      at 0 range 18 .. 18;
      DBNCEDONE        at 0 range 19 .. 19;
      Reserved_20_31   at 0 range 20 .. 31;
   end record;

   subtype GAHBCFG_HBSTLEN_Field is ESP32S3_Registers.UInt4;

   type GAHBCFG_Register is record
      GLBLLNTRMSK      : Boolean := False;
      HBSTLEN          : GAHBCFG_HBSTLEN_Field := 16#0#;
      DMAEN            : Boolean := False;
      --  unspecified
      Reserved_6_6     : ESP32S3_Registers.Bit := 16#0#;
      NPTXFEMPLVL      : Boolean := False;
      PTXFEMPLVL       : Boolean := False;
      --  unspecified
      Reserved_9_20    : ESP32S3_Registers.UInt12 := 16#0#;
      REMMEMSUPP       : Boolean := False;
      NOTIALLDMAWRIT   : Boolean := False;
      AHBSINGLE        : Boolean := False;
      INVDESCENDIANESS : Boolean := False;
      --  unspecified
      Reserved_25_31   : ESP32S3_Registers.UInt7 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GAHBCFG_Register use record
      GLBLLNTRMSK      at 0 range 0 .. 0;
      HBSTLEN          at 0 range 1 .. 4;
      DMAEN            at 0 range 5 .. 5;
      Reserved_6_6     at 0 range 6 .. 6;
      NPTXFEMPLVL      at 0 range 7 .. 7;
      PTXFEMPLVL       at 0 range 8 .. 8;
      Reserved_9_20    at 0 range 9 .. 20;
      REMMEMSUPP       at 0 range 21 .. 21;
      NOTIALLDMAWRIT   at 0 range 22 .. 22;
      AHBSINGLE        at 0 range 23 .. 23;
      INVDESCENDIANESS at 0 range 24 .. 24;
      Reserved_25_31   at 0 range 25 .. 31;
   end record;

   subtype GUSBCFG_TOUTCAL_Field is ESP32S3_Registers.UInt3;
   subtype GUSBCFG_USBTRDTIM_Field is ESP32S3_Registers.UInt4;

   type GUSBCFG_Register is record
      TOUTCAL        : GUSBCFG_TOUTCAL_Field := 16#0#;
      PHYIF          : Boolean := False;
      --  Read-only.
      ULPI_UTMI_SEL  : Boolean := False;
      FSINTF         : Boolean := False;
      --  Read-only.
      PHYSEL         : Boolean := True;
      --  unspecified
      Reserved_7_7   : ESP32S3_Registers.Bit := 16#0#;
      SRPCAP         : Boolean := False;
      HNPCAP         : Boolean := False;
      USBTRDTIM      : GUSBCFG_USBTRDTIM_Field := 16#5#;
      --  unspecified
      Reserved_14_21 : ESP32S3_Registers.Byte := 16#0#;
      TERMSELDLPULSE : Boolean := False;
      --  unspecified
      Reserved_23_27 : ESP32S3_Registers.UInt5 := 16#0#;
      TXENDDELAY     : Boolean := False;
      FORCEHSTMODE   : Boolean := False;
      FORCEDEVMODE   : Boolean := False;
      CORRUPTTXPKT   : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GUSBCFG_Register use record
      TOUTCAL        at 0 range 0 .. 2;
      PHYIF          at 0 range 3 .. 3;
      ULPI_UTMI_SEL  at 0 range 4 .. 4;
      FSINTF         at 0 range 5 .. 5;
      PHYSEL         at 0 range 6 .. 6;
      Reserved_7_7   at 0 range 7 .. 7;
      SRPCAP         at 0 range 8 .. 8;
      HNPCAP         at 0 range 9 .. 9;
      USBTRDTIM      at 0 range 10 .. 13;
      Reserved_14_21 at 0 range 14 .. 21;
      TERMSELDLPULSE at 0 range 22 .. 22;
      Reserved_23_27 at 0 range 23 .. 27;
      TXENDDELAY     at 0 range 28 .. 28;
      FORCEHSTMODE   at 0 range 29 .. 29;
      FORCEDEVMODE   at 0 range 30 .. 30;
      CORRUPTTXPKT   at 0 range 31 .. 31;
   end record;

   subtype GRSTCTL_TXFNUM_Field is ESP32S3_Registers.UInt5;

   type GRSTCTL_Register is record
      CSFTRST        : Boolean := False;
      PIUFSSFTRST    : Boolean := False;
      FRMCNTRRST     : Boolean := False;
      --  unspecified
      Reserved_3_3   : ESP32S3_Registers.Bit := 16#0#;
      RXFFLSH        : Boolean := False;
      TXFFLSH        : Boolean := False;
      TXFNUM         : GRSTCTL_TXFNUM_Field := 16#0#;
      --  unspecified
      Reserved_11_29 : ESP32S3_Registers.UInt19 := 16#0#;
      --  Read-only.
      DMAREQ         : Boolean := False;
      --  Read-only.
      AHBIDLE        : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GRSTCTL_Register use record
      CSFTRST        at 0 range 0 .. 0;
      PIUFSSFTRST    at 0 range 1 .. 1;
      FRMCNTRRST     at 0 range 2 .. 2;
      Reserved_3_3   at 0 range 3 .. 3;
      RXFFLSH        at 0 range 4 .. 4;
      TXFFLSH        at 0 range 5 .. 5;
      TXFNUM         at 0 range 6 .. 10;
      Reserved_11_29 at 0 range 11 .. 29;
      DMAREQ         at 0 range 30 .. 30;
      AHBIDLE        at 0 range 31 .. 31;
   end record;

   type GINTSTS_Register is record
      --  Read-only.
      CURMOD_INT     : Boolean := False;
      MODEMIS        : Boolean := False;
      --  Read-only.
      OTGINT         : Boolean := False;
      SOF            : Boolean := False;
      --  Read-only.
      RXFLVI         : Boolean := False;
      --  Read-only.
      NPTXFEMP       : Boolean := False;
      --  Read-only.
      GINNAKEFF      : Boolean := False;
      --  Read-only.
      GOUTNAKEFF     : Boolean := False;
      --  unspecified
      Reserved_8_9   : ESP32S3_Registers.UInt2 := 16#0#;
      ERLYSUSP       : Boolean := False;
      USBSUSP        : Boolean := False;
      USBRST         : Boolean := False;
      ENUMDONE       : Boolean := False;
      ISOOUTDROP     : Boolean := False;
      EOPF           : Boolean := False;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      EPMIS          : Boolean := False;
      --  Read-only.
      IEPINT         : Boolean := False;
      --  Read-only.
      OEPINT         : Boolean := False;
      INCOMPISOIN    : Boolean := False;
      INCOMPIP       : Boolean := False;
      FETSUSP        : Boolean := False;
      RESETDET       : Boolean := False;
      --  Read-only.
      PRTLNT         : Boolean := False;
      --  Read-only.
      HCHLNT         : Boolean := False;
      --  Read-only.
      PTXFEMP        : Boolean := False;
      --  unspecified
      Reserved_27_27 : ESP32S3_Registers.Bit := 16#0#;
      CONIDSTSCHNG   : Boolean := False;
      DISCONNINT     : Boolean := False;
      SESSREQINT     : Boolean := False;
      WKUPINT        : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GINTSTS_Register use record
      CURMOD_INT     at 0 range 0 .. 0;
      MODEMIS        at 0 range 1 .. 1;
      OTGINT         at 0 range 2 .. 2;
      SOF            at 0 range 3 .. 3;
      RXFLVI         at 0 range 4 .. 4;
      NPTXFEMP       at 0 range 5 .. 5;
      GINNAKEFF      at 0 range 6 .. 6;
      GOUTNAKEFF     at 0 range 7 .. 7;
      Reserved_8_9   at 0 range 8 .. 9;
      ERLYSUSP       at 0 range 10 .. 10;
      USBSUSP        at 0 range 11 .. 11;
      USBRST         at 0 range 12 .. 12;
      ENUMDONE       at 0 range 13 .. 13;
      ISOOUTDROP     at 0 range 14 .. 14;
      EOPF           at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      EPMIS          at 0 range 17 .. 17;
      IEPINT         at 0 range 18 .. 18;
      OEPINT         at 0 range 19 .. 19;
      INCOMPISOIN    at 0 range 20 .. 20;
      INCOMPIP       at 0 range 21 .. 21;
      FETSUSP        at 0 range 22 .. 22;
      RESETDET       at 0 range 23 .. 23;
      PRTLNT         at 0 range 24 .. 24;
      HCHLNT         at 0 range 25 .. 25;
      PTXFEMP        at 0 range 26 .. 26;
      Reserved_27_27 at 0 range 27 .. 27;
      CONIDSTSCHNG   at 0 range 28 .. 28;
      DISCONNINT     at 0 range 29 .. 29;
      SESSREQINT     at 0 range 30 .. 30;
      WKUPINT        at 0 range 31 .. 31;
   end record;

   type GINTMSK_Register is record
      --  unspecified
      Reserved_0_0    : ESP32S3_Registers.Bit := 16#0#;
      MODEMISMSK      : Boolean := False;
      OTGINTMSK       : Boolean := False;
      SOFMSK          : Boolean := False;
      RXFLVIMSK       : Boolean := False;
      NPTXFEMPMSK     : Boolean := False;
      GINNAKEFFMSK    : Boolean := False;
      GOUTNACKEFFMSK  : Boolean := False;
      --  unspecified
      Reserved_8_9    : ESP32S3_Registers.UInt2 := 16#0#;
      ERLYSUSPMSK     : Boolean := False;
      USBSUSPMSK      : Boolean := False;
      USBRSTMSK       : Boolean := False;
      ENUMDONEMSK     : Boolean := False;
      ISOOUTDROPMSK   : Boolean := False;
      EOPFMSK         : Boolean := False;
      --  unspecified
      Reserved_16_16  : ESP32S3_Registers.Bit := 16#0#;
      EPMISMSK        : Boolean := False;
      IEPINTMSK       : Boolean := False;
      OEPINTMSK       : Boolean := False;
      INCOMPISOINMSK  : Boolean := False;
      INCOMPIPMSK     : Boolean := False;
      FETSUSPMSK      : Boolean := False;
      RESETDETMSK     : Boolean := False;
      PRTLNTMSK       : Boolean := False;
      HCHINTMSK       : Boolean := False;
      PTXFEMPMSK      : Boolean := False;
      --  unspecified
      Reserved_27_27  : ESP32S3_Registers.Bit := 16#0#;
      CONIDSTSCHNGMSK : Boolean := False;
      DISCONNINTMSK   : Boolean := False;
      SESSREQINTMSK   : Boolean := False;
      WKUPINTMSK      : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GINTMSK_Register use record
      Reserved_0_0    at 0 range 0 .. 0;
      MODEMISMSK      at 0 range 1 .. 1;
      OTGINTMSK       at 0 range 2 .. 2;
      SOFMSK          at 0 range 3 .. 3;
      RXFLVIMSK       at 0 range 4 .. 4;
      NPTXFEMPMSK     at 0 range 5 .. 5;
      GINNAKEFFMSK    at 0 range 6 .. 6;
      GOUTNACKEFFMSK  at 0 range 7 .. 7;
      Reserved_8_9    at 0 range 8 .. 9;
      ERLYSUSPMSK     at 0 range 10 .. 10;
      USBSUSPMSK      at 0 range 11 .. 11;
      USBRSTMSK       at 0 range 12 .. 12;
      ENUMDONEMSK     at 0 range 13 .. 13;
      ISOOUTDROPMSK   at 0 range 14 .. 14;
      EOPFMSK         at 0 range 15 .. 15;
      Reserved_16_16  at 0 range 16 .. 16;
      EPMISMSK        at 0 range 17 .. 17;
      IEPINTMSK       at 0 range 18 .. 18;
      OEPINTMSK       at 0 range 19 .. 19;
      INCOMPISOINMSK  at 0 range 20 .. 20;
      INCOMPIPMSK     at 0 range 21 .. 21;
      FETSUSPMSK      at 0 range 22 .. 22;
      RESETDETMSK     at 0 range 23 .. 23;
      PRTLNTMSK       at 0 range 24 .. 24;
      HCHINTMSK       at 0 range 25 .. 25;
      PTXFEMPMSK      at 0 range 26 .. 26;
      Reserved_27_27  at 0 range 27 .. 27;
      CONIDSTSCHNGMSK at 0 range 28 .. 28;
      DISCONNINTMSK   at 0 range 29 .. 29;
      SESSREQINTMSK   at 0 range 30 .. 30;
      WKUPINTMSK      at 0 range 31 .. 31;
   end record;

   subtype GRXSTSR_G_CHNUM_Field is ESP32S3_Registers.UInt4;
   subtype GRXSTSR_G_BCNT_Field is ESP32S3_Registers.UInt11;
   subtype GRXSTSR_G_DPID_Field is ESP32S3_Registers.UInt2;
   subtype GRXSTSR_G_PKTSTS_Field is ESP32S3_Registers.UInt4;
   subtype GRXSTSR_G_FN_Field is ESP32S3_Registers.UInt4;

   type GRXSTSR_Register is record
      --  Read-only.
      G_CHNUM        : GRXSTSR_G_CHNUM_Field;
      --  Read-only.
      G_BCNT         : GRXSTSR_G_BCNT_Field;
      --  Read-only.
      G_DPID         : GRXSTSR_G_DPID_Field;
      --  Read-only.
      G_PKTSTS       : GRXSTSR_G_PKTSTS_Field;
      --  Read-only.
      G_FN           : GRXSTSR_G_FN_Field;
      --  unspecified
      Reserved_25_31 : ESP32S3_Registers.UInt7;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GRXSTSR_Register use record
      G_CHNUM        at 0 range 0 .. 3;
      G_BCNT         at 0 range 4 .. 14;
      G_DPID         at 0 range 15 .. 16;
      G_PKTSTS       at 0 range 17 .. 20;
      G_FN           at 0 range 21 .. 24;
      Reserved_25_31 at 0 range 25 .. 31;
   end record;

   subtype GRXSTSP_CHNUM_Field is ESP32S3_Registers.UInt4;
   subtype GRXSTSP_BCNT_Field is ESP32S3_Registers.UInt11;
   subtype GRXSTSP_DPID_Field is ESP32S3_Registers.UInt2;
   subtype GRXSTSP_PKTSTS_Field is ESP32S3_Registers.UInt4;
   subtype GRXSTSP_FN_Field is ESP32S3_Registers.UInt4;

   type GRXSTSP_Register is record
      --  Read-only.
      CHNUM          : GRXSTSP_CHNUM_Field;
      --  Read-only.
      BCNT           : GRXSTSP_BCNT_Field;
      --  Read-only.
      DPID           : GRXSTSP_DPID_Field;
      --  Read-only.
      PKTSTS         : GRXSTSP_PKTSTS_Field;
      --  Read-only.
      FN             : GRXSTSP_FN_Field;
      --  unspecified
      Reserved_25_31 : ESP32S3_Registers.UInt7;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GRXSTSP_Register use record
      CHNUM          at 0 range 0 .. 3;
      BCNT           at 0 range 4 .. 14;
      DPID           at 0 range 15 .. 16;
      PKTSTS         at 0 range 17 .. 20;
      FN             at 0 range 21 .. 24;
      Reserved_25_31 at 0 range 25 .. 31;
   end record;

   subtype GRXFSIZ_RXFDEP_Field is ESP32S3_Registers.UInt16;

   type GRXFSIZ_Register is record
      RXFDEP         : GRXFSIZ_RXFDEP_Field := 16#100#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GRXFSIZ_Register use record
      RXFDEP         at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype GNPTXFSIZ_NPTXFSTADDR_Field is ESP32S3_Registers.UInt16;
   subtype GNPTXFSIZ_NPTXFDEP_Field is ESP32S3_Registers.UInt16;

   type GNPTXFSIZ_Register is record
      NPTXFSTADDR : GNPTXFSIZ_NPTXFSTADDR_Field := 16#100#;
      NPTXFDEP    : GNPTXFSIZ_NPTXFDEP_Field := 16#100#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GNPTXFSIZ_Register use record
      NPTXFSTADDR at 0 range 0 .. 15;
      NPTXFDEP    at 0 range 16 .. 31;
   end record;

   subtype GNPTXSTS_NPTXFSPCAVAIL_Field is ESP32S3_Registers.UInt16;
   subtype GNPTXSTS_NPTXQSPCAVAIL_Field is ESP32S3_Registers.UInt4;
   subtype GNPTXSTS_NPTXQTOP_Field is ESP32S3_Registers.UInt7;

   type GNPTXSTS_Register is record
      --  Read-only.
      NPTXFSPCAVAIL  : GNPTXSTS_NPTXFSPCAVAIL_Field;
      --  Read-only.
      NPTXQSPCAVAIL  : GNPTXSTS_NPTXQSPCAVAIL_Field;
      --  unspecified
      Reserved_20_23 : ESP32S3_Registers.UInt4;
      --  Read-only.
      NPTXQTOP       : GNPTXSTS_NPTXQTOP_Field;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GNPTXSTS_Register use record
      NPTXFSPCAVAIL  at 0 range 0 .. 15;
      NPTXQSPCAVAIL  at 0 range 16 .. 19;
      Reserved_20_23 at 0 range 20 .. 23;
      NPTXQTOP       at 0 range 24 .. 30;
      Reserved_31_31 at 0 range 31 .. 31;
   end record;

   subtype GHWCFG2_OTGMODE_Field is ESP32S3_Registers.UInt3;
   subtype GHWCFG2_OTGARCH_Field is ESP32S3_Registers.UInt2;
   subtype GHWCFG2_HSPHYTYPE_Field is ESP32S3_Registers.UInt2;
   subtype GHWCFG2_FSPHYTYPE_Field is ESP32S3_Registers.UInt2;
   subtype GHWCFG2_NUMDEVEPS_Field is ESP32S3_Registers.UInt4;
   subtype GHWCFG2_NUMHSTCHNL_Field is ESP32S3_Registers.UInt4;
   subtype GHWCFG2_NPTXQDEPTH_Field is ESP32S3_Registers.UInt2;
   subtype GHWCFG2_PTXQDEPTH_Field is ESP32S3_Registers.UInt2;
   subtype GHWCFG2_TKNQDEPTH_Field is ESP32S3_Registers.UInt5;

   type GHWCFG2_Register is record
      --  Read-only.
      OTGMODE           : GHWCFG2_OTGMODE_Field;
      --  Read-only.
      OTGARCH           : GHWCFG2_OTGARCH_Field;
      --  Read-only.
      SINGPNT           : Boolean;
      --  Read-only.
      HSPHYTYPE         : GHWCFG2_HSPHYTYPE_Field;
      --  Read-only.
      FSPHYTYPE         : GHWCFG2_FSPHYTYPE_Field;
      --  Read-only.
      NUMDEVEPS         : GHWCFG2_NUMDEVEPS_Field;
      --  Read-only.
      NUMHSTCHNL        : GHWCFG2_NUMHSTCHNL_Field;
      --  Read-only.
      PERIOSUPPORT      : Boolean;
      --  Read-only.
      DYNFIFOSIZING     : Boolean;
      --  Read-only.
      MULTIPROCINTRPT   : Boolean;
      --  unspecified
      Reserved_21_21    : ESP32S3_Registers.Bit;
      --  Read-only.
      NPTXQDEPTH        : GHWCFG2_NPTXQDEPTH_Field;
      --  Read-only.
      PTXQDEPTH         : GHWCFG2_PTXQDEPTH_Field;
      --  Read-only.
      TKNQDEPTH         : GHWCFG2_TKNQDEPTH_Field;
      --  Read-only.
      OTG_ENABLE_IC_USB : Boolean;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GHWCFG2_Register use record
      OTGMODE           at 0 range 0 .. 2;
      OTGARCH           at 0 range 3 .. 4;
      SINGPNT           at 0 range 5 .. 5;
      HSPHYTYPE         at 0 range 6 .. 7;
      FSPHYTYPE         at 0 range 8 .. 9;
      NUMDEVEPS         at 0 range 10 .. 13;
      NUMHSTCHNL        at 0 range 14 .. 17;
      PERIOSUPPORT      at 0 range 18 .. 18;
      DYNFIFOSIZING     at 0 range 19 .. 19;
      MULTIPROCINTRPT   at 0 range 20 .. 20;
      Reserved_21_21    at 0 range 21 .. 21;
      NPTXQDEPTH        at 0 range 22 .. 23;
      PTXQDEPTH         at 0 range 24 .. 25;
      TKNQDEPTH         at 0 range 26 .. 30;
      OTG_ENABLE_IC_USB at 0 range 31 .. 31;
   end record;

   subtype GHWCFG3_XFERSIZEWIDTH_Field is ESP32S3_Registers.UInt4;
   subtype GHWCFG3_PKTSIZEWIDTH_Field is ESP32S3_Registers.UInt3;
   subtype GHWCFG3_DFIFODEPTH_Field is ESP32S3_Registers.UInt16;

   type GHWCFG3_Register is record
      --  Read-only.
      XFERSIZEWIDTH : GHWCFG3_XFERSIZEWIDTH_Field;
      --  Read-only.
      PKTSIZEWIDTH  : GHWCFG3_PKTSIZEWIDTH_Field;
      --  Read-only.
      OTGEN         : Boolean;
      --  Read-only.
      I2CINTSEL     : Boolean;
      --  Read-only.
      VNDCTLSUPT    : Boolean;
      --  Read-only.
      OPTFEATURE    : Boolean;
      --  Read-only.
      RSTTYPE       : Boolean;
      --  Read-only.
      ADPSUPPORT    : Boolean;
      --  Read-only.
      HSICMODE      : Boolean;
      --  Read-only.
      BCSUPPORT     : Boolean;
      --  Read-only.
      LPMMODE       : Boolean;
      --  Read-only.
      DFIFODEPTH    : GHWCFG3_DFIFODEPTH_Field;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GHWCFG3_Register use record
      XFERSIZEWIDTH at 0 range 0 .. 3;
      PKTSIZEWIDTH  at 0 range 4 .. 6;
      OTGEN         at 0 range 7 .. 7;
      I2CINTSEL     at 0 range 8 .. 8;
      VNDCTLSUPT    at 0 range 9 .. 9;
      OPTFEATURE    at 0 range 10 .. 10;
      RSTTYPE       at 0 range 11 .. 11;
      ADPSUPPORT    at 0 range 12 .. 12;
      HSICMODE      at 0 range 13 .. 13;
      BCSUPPORT     at 0 range 14 .. 14;
      LPMMODE       at 0 range 15 .. 15;
      DFIFODEPTH    at 0 range 16 .. 31;
   end record;

   subtype GHWCFG4_G_NUMDEVPERIOEPS_Field is ESP32S3_Registers.UInt4;
   subtype GHWCFG4_G_PHYDATAWIDTH_Field is ESP32S3_Registers.UInt2;
   subtype GHWCFG4_G_NUMCTLEPS_Field is ESP32S3_Registers.UInt4;
   subtype GHWCFG4_G_INEPS_Field is ESP32S3_Registers.UInt4;

   type GHWCFG4_Register is record
      --  Read-only.
      G_NUMDEVPERIOEPS      : GHWCFG4_G_NUMDEVPERIOEPS_Field;
      --  Read-only.
      G_PARTIALPWRDN        : Boolean;
      --  Read-only.
      G_AHBFREQ             : Boolean;
      --  Read-only.
      G_HIBERNATION         : Boolean;
      --  Read-only.
      G_EXTENDEDHIBERNATION : Boolean;
      --  unspecified
      Reserved_8_11         : ESP32S3_Registers.UInt4;
      --  Read-only.
      G_ACGSUPT             : Boolean;
      --  Read-only.
      G_ENHANCEDLPMSUPT     : Boolean;
      --  Read-only.
      G_PHYDATAWIDTH        : GHWCFG4_G_PHYDATAWIDTH_Field;
      --  Read-only.
      G_NUMCTLEPS           : GHWCFG4_G_NUMCTLEPS_Field;
      --  Read-only.
      G_IDDQFLTR            : Boolean;
      --  Read-only.
      G_VBUSVALIDFLTR       : Boolean;
      --  Read-only.
      G_AVALIDFLTR          : Boolean;
      --  Read-only.
      G_BVALIDFLTR          : Boolean;
      --  Read-only.
      G_SESSENDFLTR         : Boolean;
      --  Read-only.
      G_DEDFIFOMODE         : Boolean;
      --  Read-only.
      G_INEPS               : GHWCFG4_G_INEPS_Field;
      --  Read-only.
      G_DESCDMAENABLED      : Boolean;
      --  Read-only.
      G_DESCDMA             : Boolean;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GHWCFG4_Register use record
      G_NUMDEVPERIOEPS      at 0 range 0 .. 3;
      G_PARTIALPWRDN        at 0 range 4 .. 4;
      G_AHBFREQ             at 0 range 5 .. 5;
      G_HIBERNATION         at 0 range 6 .. 6;
      G_EXTENDEDHIBERNATION at 0 range 7 .. 7;
      Reserved_8_11         at 0 range 8 .. 11;
      G_ACGSUPT             at 0 range 12 .. 12;
      G_ENHANCEDLPMSUPT     at 0 range 13 .. 13;
      G_PHYDATAWIDTH        at 0 range 14 .. 15;
      G_NUMCTLEPS           at 0 range 16 .. 19;
      G_IDDQFLTR            at 0 range 20 .. 20;
      G_VBUSVALIDFLTR       at 0 range 21 .. 21;
      G_AVALIDFLTR          at 0 range 22 .. 22;
      G_BVALIDFLTR          at 0 range 23 .. 23;
      G_SESSENDFLTR         at 0 range 24 .. 24;
      G_DEDFIFOMODE         at 0 range 25 .. 25;
      G_INEPS               at 0 range 26 .. 29;
      G_DESCDMAENABLED      at 0 range 30 .. 30;
      G_DESCDMA             at 0 range 31 .. 31;
   end record;

   subtype GDFIFOCFG_GDFIFOCFG_Field is ESP32S3_Registers.UInt16;
   subtype GDFIFOCFG_EPINFOBASEADDR_Field is ESP32S3_Registers.UInt16;

   type GDFIFOCFG_Register is record
      GDFIFOCFG      : GDFIFOCFG_GDFIFOCFG_Field := 16#0#;
      EPINFOBASEADDR : GDFIFOCFG_EPINFOBASEADDR_Field := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for GDFIFOCFG_Register use record
      GDFIFOCFG      at 0 range 0 .. 15;
      EPINFOBASEADDR at 0 range 16 .. 31;
   end record;

   subtype HPTXFSIZ_PTXFSTADDR_Field is ESP32S3_Registers.UInt16;
   subtype HPTXFSIZ_PTXFSIZE_Field is ESP32S3_Registers.UInt16;

   type HPTXFSIZ_Register is record
      PTXFSTADDR : HPTXFSIZ_PTXFSTADDR_Field := 16#200#;
      PTXFSIZE   : HPTXFSIZ_PTXFSIZE_Field := 16#1000#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HPTXFSIZ_Register use record
      PTXFSTADDR at 0 range 0 .. 15;
      PTXFSIZE   at 0 range 16 .. 31;
   end record;

   subtype DIEPTXF1_INEP1TXFSTADDR_Field is ESP32S3_Registers.UInt16;
   subtype DIEPTXF1_INEP1TXFDEP_Field is ESP32S3_Registers.UInt16;

   type DIEPTXF1_Register is record
      INEP1TXFSTADDR : DIEPTXF1_INEP1TXFSTADDR_Field := 16#200#;
      INEP1TXFDEP    : DIEPTXF1_INEP1TXFDEP_Field := 16#1000#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPTXF1_Register use record
      INEP1TXFSTADDR at 0 range 0 .. 15;
      INEP1TXFDEP    at 0 range 16 .. 31;
   end record;

   subtype DIEPTXF2_INEP2TXFSTADDR_Field is ESP32S3_Registers.UInt16;
   subtype DIEPTXF2_INEP2TXFDEP_Field is ESP32S3_Registers.UInt16;

   type DIEPTXF2_Register is record
      INEP2TXFSTADDR : DIEPTXF2_INEP2TXFSTADDR_Field := 16#200#;
      INEP2TXFDEP    : DIEPTXF2_INEP2TXFDEP_Field := 16#1000#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPTXF2_Register use record
      INEP2TXFSTADDR at 0 range 0 .. 15;
      INEP2TXFDEP    at 0 range 16 .. 31;
   end record;

   subtype DIEPTXF3_INEP3TXFSTADDR_Field is ESP32S3_Registers.UInt16;
   subtype DIEPTXF3_INEP3TXFDEP_Field is ESP32S3_Registers.UInt16;

   type DIEPTXF3_Register is record
      INEP3TXFSTADDR : DIEPTXF3_INEP3TXFSTADDR_Field := 16#200#;
      INEP3TXFDEP    : DIEPTXF3_INEP3TXFDEP_Field := 16#1000#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPTXF3_Register use record
      INEP3TXFSTADDR at 0 range 0 .. 15;
      INEP3TXFDEP    at 0 range 16 .. 31;
   end record;

   subtype DIEPTXF4_INEP4TXFSTADDR_Field is ESP32S3_Registers.UInt16;
   subtype DIEPTXF4_INEP4TXFDEP_Field is ESP32S3_Registers.UInt16;

   type DIEPTXF4_Register is record
      INEP4TXFSTADDR : DIEPTXF4_INEP4TXFSTADDR_Field := 16#200#;
      INEP4TXFDEP    : DIEPTXF4_INEP4TXFDEP_Field := 16#1000#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPTXF4_Register use record
      INEP4TXFSTADDR at 0 range 0 .. 15;
      INEP4TXFDEP    at 0 range 16 .. 31;
   end record;

   subtype HCFG_H_FSLSPCLKSEL_Field is ESP32S3_Registers.UInt2;
   subtype HCFG_H_FRLISTEN_Field is ESP32S3_Registers.UInt2;

   type HCFG_Register is record
      H_FSLSPCLKSEL  : HCFG_H_FSLSPCLKSEL_Field := 16#0#;
      H_FSLSSUPP     : Boolean := False;
      --  unspecified
      Reserved_3_6   : ESP32S3_Registers.UInt4 := 16#0#;
      H_ENA32KHZS    : Boolean := False;
      --  unspecified
      Reserved_8_22  : ESP32S3_Registers.UInt15 := 16#0#;
      H_DESCDMA      : Boolean := False;
      H_FRLISTEN     : HCFG_H_FRLISTEN_Field := 16#0#;
      H_PERSCHEDENA  : Boolean := False;
      --  unspecified
      Reserved_27_30 : ESP32S3_Registers.UInt4 := 16#0#;
      H_MODECHTIMEN  : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCFG_Register use record
      H_FSLSPCLKSEL  at 0 range 0 .. 1;
      H_FSLSSUPP     at 0 range 2 .. 2;
      Reserved_3_6   at 0 range 3 .. 6;
      H_ENA32KHZS    at 0 range 7 .. 7;
      Reserved_8_22  at 0 range 8 .. 22;
      H_DESCDMA      at 0 range 23 .. 23;
      H_FRLISTEN     at 0 range 24 .. 25;
      H_PERSCHEDENA  at 0 range 26 .. 26;
      Reserved_27_30 at 0 range 27 .. 30;
      H_MODECHTIMEN  at 0 range 31 .. 31;
   end record;

   subtype HFIR_FRINT_Field is ESP32S3_Registers.UInt16;

   type HFIR_Register is record
      FRINT          : HFIR_FRINT_Field := 16#17D7#;
      HFIRRLDCTRL    : Boolean := False;
      --  unspecified
      Reserved_17_31 : ESP32S3_Registers.UInt15 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HFIR_Register use record
      FRINT          at 0 range 0 .. 15;
      HFIRRLDCTRL    at 0 range 16 .. 16;
      Reserved_17_31 at 0 range 17 .. 31;
   end record;

   subtype HFNUM_FRNUM_Field is ESP32S3_Registers.UInt14;
   subtype HFNUM_FRREM_Field is ESP32S3_Registers.UInt16;

   type HFNUM_Register is record
      --  Read-only.
      FRNUM          : HFNUM_FRNUM_Field;
      --  unspecified
      Reserved_14_15 : ESP32S3_Registers.UInt2;
      --  Read-only.
      FRREM          : HFNUM_FRREM_Field;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HFNUM_Register use record
      FRNUM          at 0 range 0 .. 13;
      Reserved_14_15 at 0 range 14 .. 15;
      FRREM          at 0 range 16 .. 31;
   end record;

   subtype HPTXSTS_PTXFSPCAVAIL_Field is ESP32S3_Registers.UInt16;
   subtype HPTXSTS_PTXQSPCAVAIL_Field is ESP32S3_Registers.UInt5;
   subtype HPTXSTS_PTXQTOP_Field is ESP32S3_Registers.Byte;

   type HPTXSTS_Register is record
      --  Read-only.
      PTXFSPCAVAIL   : HPTXSTS_PTXFSPCAVAIL_Field;
      --  Read-only.
      PTXQSPCAVAIL   : HPTXSTS_PTXQSPCAVAIL_Field;
      --  unspecified
      Reserved_21_23 : ESP32S3_Registers.UInt3;
      --  Read-only.
      PTXQTOP        : HPTXSTS_PTXQTOP_Field;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HPTXSTS_Register use record
      PTXFSPCAVAIL   at 0 range 0 .. 15;
      PTXQSPCAVAIL   at 0 range 16 .. 20;
      Reserved_21_23 at 0 range 21 .. 23;
      PTXQTOP        at 0 range 24 .. 31;
   end record;

   subtype HAINT_HAINT_Field is ESP32S3_Registers.Byte;

   type HAINT_Register is record
      --  Read-only.
      HAINT         : HAINT_HAINT_Field;
      --  unspecified
      Reserved_8_31 : ESP32S3_Registers.UInt24;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HAINT_Register use record
      HAINT         at 0 range 0 .. 7;
      Reserved_8_31 at 0 range 8 .. 31;
   end record;

   subtype HAINTMSK_HAINTMSK_Field is ESP32S3_Registers.Byte;

   type HAINTMSK_Register is record
      HAINTMSK      : HAINTMSK_HAINTMSK_Field := 16#0#;
      --  unspecified
      Reserved_8_31 : ESP32S3_Registers.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HAINTMSK_Register use record
      HAINTMSK      at 0 range 0 .. 7;
      Reserved_8_31 at 0 range 8 .. 31;
   end record;

   subtype HPRT_PRTLNSTS_Field is ESP32S3_Registers.UInt2;
   subtype HPRT_PRTTSTCTL_Field is ESP32S3_Registers.UInt4;
   subtype HPRT_PRTSPD_Field is ESP32S3_Registers.UInt2;

   type HPRT_Register is record
      --  Read-only.
      PRTCONNSTS     : Boolean := False;
      PRTCONNDET     : Boolean := False;
      PRTENA         : Boolean := False;
      PRTENCHNG      : Boolean := False;
      --  Read-only.
      PRTOVRCURRACT  : Boolean := False;
      PRTOVRCURRCHNG : Boolean := False;
      PRTRES         : Boolean := False;
      PRTSUSP        : Boolean := False;
      PRTRST         : Boolean := False;
      --  unspecified
      Reserved_9_9   : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      PRTLNSTS       : HPRT_PRTLNSTS_Field := 16#0#;
      PRTPWR         : Boolean := False;
      PRTTSTCTL      : HPRT_PRTTSTCTL_Field := 16#0#;
      --  Read-only.
      PRTSPD         : HPRT_PRTSPD_Field := 16#0#;
      --  unspecified
      Reserved_19_31 : ESP32S3_Registers.UInt13 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HPRT_Register use record
      PRTCONNSTS     at 0 range 0 .. 0;
      PRTCONNDET     at 0 range 1 .. 1;
      PRTENA         at 0 range 2 .. 2;
      PRTENCHNG      at 0 range 3 .. 3;
      PRTOVRCURRACT  at 0 range 4 .. 4;
      PRTOVRCURRCHNG at 0 range 5 .. 5;
      PRTRES         at 0 range 6 .. 6;
      PRTSUSP        at 0 range 7 .. 7;
      PRTRST         at 0 range 8 .. 8;
      Reserved_9_9   at 0 range 9 .. 9;
      PRTLNSTS       at 0 range 10 .. 11;
      PRTPWR         at 0 range 12 .. 12;
      PRTTSTCTL      at 0 range 13 .. 16;
      PRTSPD         at 0 range 17 .. 18;
      Reserved_19_31 at 0 range 19 .. 31;
   end record;

   subtype HCCHAR0_H_MPS0_Field is ESP32S3_Registers.UInt11;
   subtype HCCHAR0_H_EPNUM0_Field is ESP32S3_Registers.UInt4;
   subtype HCCHAR0_H_EPTYPE0_Field is ESP32S3_Registers.UInt2;
   subtype HCCHAR0_H_DEVADDR0_Field is ESP32S3_Registers.UInt7;

   type HCCHAR0_Register is record
      H_MPS0         : HCCHAR0_H_MPS0_Field := 16#0#;
      H_EPNUM0       : HCCHAR0_H_EPNUM0_Field := 16#0#;
      H_EPDIR0       : Boolean := False;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      H_LSPDDEV0     : Boolean := False;
      H_EPTYPE0      : HCCHAR0_H_EPTYPE0_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      H_EC0          : Boolean := False;
      H_DEVADDR0     : HCCHAR0_H_DEVADDR0_Field := 16#0#;
      H_ODDFRM0      : Boolean := False;
      H_CHDIS0       : Boolean := False;
      H_CHENA0       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCCHAR0_Register use record
      H_MPS0         at 0 range 0 .. 10;
      H_EPNUM0       at 0 range 11 .. 14;
      H_EPDIR0       at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      H_LSPDDEV0     at 0 range 17 .. 17;
      H_EPTYPE0      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      H_EC0          at 0 range 21 .. 21;
      H_DEVADDR0     at 0 range 22 .. 28;
      H_ODDFRM0      at 0 range 29 .. 29;
      H_CHDIS0       at 0 range 30 .. 30;
      H_CHENA0       at 0 range 31 .. 31;
   end record;

   type HCINT0_Register is record
      H_XFERCOMPL0         : Boolean := False;
      H_CHHLTD0            : Boolean := False;
      H_AHBERR0            : Boolean := False;
      H_STALL0             : Boolean := False;
      H_NACK0              : Boolean := False;
      H_ACK0               : Boolean := False;
      H_NYET0              : Boolean := False;
      H_XACTERR0           : Boolean := False;
      H_BBLERR0            : Boolean := False;
      H_FRMOVRUN0          : Boolean := False;
      H_DATATGLERR0        : Boolean := False;
      H_BNAINTR0           : Boolean := False;
      H_XCS_XACT_ERR0      : Boolean := False;
      H_DESC_LST_ROLLINTR0 : Boolean := False;
      --  unspecified
      Reserved_14_31       : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINT0_Register use record
      H_XFERCOMPL0         at 0 range 0 .. 0;
      H_CHHLTD0            at 0 range 1 .. 1;
      H_AHBERR0            at 0 range 2 .. 2;
      H_STALL0             at 0 range 3 .. 3;
      H_NACK0              at 0 range 4 .. 4;
      H_ACK0               at 0 range 5 .. 5;
      H_NYET0              at 0 range 6 .. 6;
      H_XACTERR0           at 0 range 7 .. 7;
      H_BBLERR0            at 0 range 8 .. 8;
      H_FRMOVRUN0          at 0 range 9 .. 9;
      H_DATATGLERR0        at 0 range 10 .. 10;
      H_BNAINTR0           at 0 range 11 .. 11;
      H_XCS_XACT_ERR0      at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTR0 at 0 range 13 .. 13;
      Reserved_14_31       at 0 range 14 .. 31;
   end record;

   type HCINTMSK0_Register is record
      H_XFERCOMPLMSK0         : Boolean := False;
      H_CHHLTDMSK0            : Boolean := False;
      H_AHBERRMSK0            : Boolean := False;
      H_STALLMSK0             : Boolean := False;
      H_NAKMSK0               : Boolean := False;
      H_ACKMSK0               : Boolean := False;
      H_NYETMSK0              : Boolean := False;
      H_XACTERRMSK0           : Boolean := False;
      H_BBLERRMSK0            : Boolean := False;
      H_FRMOVRUNMSK0          : Boolean := False;
      H_DATATGLERRMSK0        : Boolean := False;
      H_BNAINTRMSK0           : Boolean := False;
      --  unspecified
      Reserved_12_12          : ESP32S3_Registers.Bit := 16#0#;
      H_DESC_LST_ROLLINTRMSK0 : Boolean := False;
      --  unspecified
      Reserved_14_31          : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINTMSK0_Register use record
      H_XFERCOMPLMSK0         at 0 range 0 .. 0;
      H_CHHLTDMSK0            at 0 range 1 .. 1;
      H_AHBERRMSK0            at 0 range 2 .. 2;
      H_STALLMSK0             at 0 range 3 .. 3;
      H_NAKMSK0               at 0 range 4 .. 4;
      H_ACKMSK0               at 0 range 5 .. 5;
      H_NYETMSK0              at 0 range 6 .. 6;
      H_XACTERRMSK0           at 0 range 7 .. 7;
      H_BBLERRMSK0            at 0 range 8 .. 8;
      H_FRMOVRUNMSK0          at 0 range 9 .. 9;
      H_DATATGLERRMSK0        at 0 range 10 .. 10;
      H_BNAINTRMSK0           at 0 range 11 .. 11;
      Reserved_12_12          at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTRMSK0 at 0 range 13 .. 13;
      Reserved_14_31          at 0 range 14 .. 31;
   end record;

   subtype HCTSIZ0_H_XFERSIZE0_Field is ESP32S3_Registers.UInt19;
   subtype HCTSIZ0_H_PKTCNT0_Field is ESP32S3_Registers.UInt10;
   subtype HCTSIZ0_H_PID0_Field is ESP32S3_Registers.UInt2;

   type HCTSIZ0_Register is record
      H_XFERSIZE0 : HCTSIZ0_H_XFERSIZE0_Field := 16#0#;
      H_PKTCNT0   : HCTSIZ0_H_PKTCNT0_Field := 16#0#;
      H_PID0      : HCTSIZ0_H_PID0_Field := 16#0#;
      H_DOPNG0    : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCTSIZ0_Register use record
      H_XFERSIZE0 at 0 range 0 .. 18;
      H_PKTCNT0   at 0 range 19 .. 28;
      H_PID0      at 0 range 29 .. 30;
      H_DOPNG0    at 0 range 31 .. 31;
   end record;

   subtype HCCHAR1_H_MPS1_Field is ESP32S3_Registers.UInt11;
   subtype HCCHAR1_H_EPNUM1_Field is ESP32S3_Registers.UInt4;
   subtype HCCHAR1_H_EPTYPE1_Field is ESP32S3_Registers.UInt2;
   subtype HCCHAR1_H_DEVADDR1_Field is ESP32S3_Registers.UInt7;

   type HCCHAR1_Register is record
      H_MPS1         : HCCHAR1_H_MPS1_Field := 16#0#;
      H_EPNUM1       : HCCHAR1_H_EPNUM1_Field := 16#0#;
      H_EPDIR1       : Boolean := False;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      H_LSPDDEV1     : Boolean := False;
      H_EPTYPE1      : HCCHAR1_H_EPTYPE1_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      H_EC1          : Boolean := False;
      H_DEVADDR1     : HCCHAR1_H_DEVADDR1_Field := 16#0#;
      H_ODDFRM1      : Boolean := False;
      H_CHDIS1       : Boolean := False;
      H_CHENA1       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCCHAR1_Register use record
      H_MPS1         at 0 range 0 .. 10;
      H_EPNUM1       at 0 range 11 .. 14;
      H_EPDIR1       at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      H_LSPDDEV1     at 0 range 17 .. 17;
      H_EPTYPE1      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      H_EC1          at 0 range 21 .. 21;
      H_DEVADDR1     at 0 range 22 .. 28;
      H_ODDFRM1      at 0 range 29 .. 29;
      H_CHDIS1       at 0 range 30 .. 30;
      H_CHENA1       at 0 range 31 .. 31;
   end record;

   type HCINT1_Register is record
      H_XFERCOMPL1         : Boolean := False;
      H_CHHLTD1            : Boolean := False;
      H_AHBERR1            : Boolean := False;
      H_STALL1             : Boolean := False;
      H_NACK1              : Boolean := False;
      H_ACK1               : Boolean := False;
      H_NYET1              : Boolean := False;
      H_XACTERR1           : Boolean := False;
      H_BBLERR1            : Boolean := False;
      H_FRMOVRUN1          : Boolean := False;
      H_DATATGLERR1        : Boolean := False;
      H_BNAINTR1           : Boolean := False;
      H_XCS_XACT_ERR1      : Boolean := False;
      H_DESC_LST_ROLLINTR1 : Boolean := False;
      --  unspecified
      Reserved_14_31       : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINT1_Register use record
      H_XFERCOMPL1         at 0 range 0 .. 0;
      H_CHHLTD1            at 0 range 1 .. 1;
      H_AHBERR1            at 0 range 2 .. 2;
      H_STALL1             at 0 range 3 .. 3;
      H_NACK1              at 0 range 4 .. 4;
      H_ACK1               at 0 range 5 .. 5;
      H_NYET1              at 0 range 6 .. 6;
      H_XACTERR1           at 0 range 7 .. 7;
      H_BBLERR1            at 0 range 8 .. 8;
      H_FRMOVRUN1          at 0 range 9 .. 9;
      H_DATATGLERR1        at 0 range 10 .. 10;
      H_BNAINTR1           at 0 range 11 .. 11;
      H_XCS_XACT_ERR1      at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTR1 at 0 range 13 .. 13;
      Reserved_14_31       at 0 range 14 .. 31;
   end record;

   type HCINTMSK1_Register is record
      H_XFERCOMPLMSK1         : Boolean := False;
      H_CHHLTDMSK1            : Boolean := False;
      H_AHBERRMSK1            : Boolean := False;
      H_STALLMSK1             : Boolean := False;
      H_NAKMSK1               : Boolean := False;
      H_ACKMSK1               : Boolean := False;
      H_NYETMSK1              : Boolean := False;
      H_XACTERRMSK1           : Boolean := False;
      H_BBLERRMSK1            : Boolean := False;
      H_FRMOVRUNMSK1          : Boolean := False;
      H_DATATGLERRMSK1        : Boolean := False;
      H_BNAINTRMSK1           : Boolean := False;
      --  unspecified
      Reserved_12_12          : ESP32S3_Registers.Bit := 16#0#;
      H_DESC_LST_ROLLINTRMSK1 : Boolean := False;
      --  unspecified
      Reserved_14_31          : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINTMSK1_Register use record
      H_XFERCOMPLMSK1         at 0 range 0 .. 0;
      H_CHHLTDMSK1            at 0 range 1 .. 1;
      H_AHBERRMSK1            at 0 range 2 .. 2;
      H_STALLMSK1             at 0 range 3 .. 3;
      H_NAKMSK1               at 0 range 4 .. 4;
      H_ACKMSK1               at 0 range 5 .. 5;
      H_NYETMSK1              at 0 range 6 .. 6;
      H_XACTERRMSK1           at 0 range 7 .. 7;
      H_BBLERRMSK1            at 0 range 8 .. 8;
      H_FRMOVRUNMSK1          at 0 range 9 .. 9;
      H_DATATGLERRMSK1        at 0 range 10 .. 10;
      H_BNAINTRMSK1           at 0 range 11 .. 11;
      Reserved_12_12          at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTRMSK1 at 0 range 13 .. 13;
      Reserved_14_31          at 0 range 14 .. 31;
   end record;

   subtype HCTSIZ1_H_XFERSIZE1_Field is ESP32S3_Registers.UInt19;
   subtype HCTSIZ1_H_PKTCNT1_Field is ESP32S3_Registers.UInt10;
   subtype HCTSIZ1_H_PID1_Field is ESP32S3_Registers.UInt2;

   type HCTSIZ1_Register is record
      H_XFERSIZE1 : HCTSIZ1_H_XFERSIZE1_Field := 16#0#;
      H_PKTCNT1   : HCTSIZ1_H_PKTCNT1_Field := 16#0#;
      H_PID1      : HCTSIZ1_H_PID1_Field := 16#0#;
      H_DOPNG1    : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCTSIZ1_Register use record
      H_XFERSIZE1 at 0 range 0 .. 18;
      H_PKTCNT1   at 0 range 19 .. 28;
      H_PID1      at 0 range 29 .. 30;
      H_DOPNG1    at 0 range 31 .. 31;
   end record;

   subtype HCCHAR2_H_MPS2_Field is ESP32S3_Registers.UInt11;
   subtype HCCHAR2_H_EPNUM2_Field is ESP32S3_Registers.UInt4;
   subtype HCCHAR2_H_EPTYPE2_Field is ESP32S3_Registers.UInt2;
   subtype HCCHAR2_H_DEVADDR2_Field is ESP32S3_Registers.UInt7;

   type HCCHAR2_Register is record
      H_MPS2         : HCCHAR2_H_MPS2_Field := 16#0#;
      H_EPNUM2       : HCCHAR2_H_EPNUM2_Field := 16#0#;
      H_EPDIR2       : Boolean := False;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      H_LSPDDEV2     : Boolean := False;
      H_EPTYPE2      : HCCHAR2_H_EPTYPE2_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      H_EC2          : Boolean := False;
      H_DEVADDR2     : HCCHAR2_H_DEVADDR2_Field := 16#0#;
      H_ODDFRM2      : Boolean := False;
      H_CHDIS2       : Boolean := False;
      H_CHENA2       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCCHAR2_Register use record
      H_MPS2         at 0 range 0 .. 10;
      H_EPNUM2       at 0 range 11 .. 14;
      H_EPDIR2       at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      H_LSPDDEV2     at 0 range 17 .. 17;
      H_EPTYPE2      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      H_EC2          at 0 range 21 .. 21;
      H_DEVADDR2     at 0 range 22 .. 28;
      H_ODDFRM2      at 0 range 29 .. 29;
      H_CHDIS2       at 0 range 30 .. 30;
      H_CHENA2       at 0 range 31 .. 31;
   end record;

   type HCINT2_Register is record
      H_XFERCOMPL2         : Boolean := False;
      H_CHHLTD2            : Boolean := False;
      H_AHBERR2            : Boolean := False;
      H_STALL2             : Boolean := False;
      H_NACK2              : Boolean := False;
      H_ACK2               : Boolean := False;
      H_NYET2              : Boolean := False;
      H_XACTERR2           : Boolean := False;
      H_BBLERR2            : Boolean := False;
      H_FRMOVRUN2          : Boolean := False;
      H_DATATGLERR2        : Boolean := False;
      H_BNAINTR2           : Boolean := False;
      H_XCS_XACT_ERR2      : Boolean := False;
      H_DESC_LST_ROLLINTR2 : Boolean := False;
      --  unspecified
      Reserved_14_31       : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINT2_Register use record
      H_XFERCOMPL2         at 0 range 0 .. 0;
      H_CHHLTD2            at 0 range 1 .. 1;
      H_AHBERR2            at 0 range 2 .. 2;
      H_STALL2             at 0 range 3 .. 3;
      H_NACK2              at 0 range 4 .. 4;
      H_ACK2               at 0 range 5 .. 5;
      H_NYET2              at 0 range 6 .. 6;
      H_XACTERR2           at 0 range 7 .. 7;
      H_BBLERR2            at 0 range 8 .. 8;
      H_FRMOVRUN2          at 0 range 9 .. 9;
      H_DATATGLERR2        at 0 range 10 .. 10;
      H_BNAINTR2           at 0 range 11 .. 11;
      H_XCS_XACT_ERR2      at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTR2 at 0 range 13 .. 13;
      Reserved_14_31       at 0 range 14 .. 31;
   end record;

   type HCINTMSK2_Register is record
      H_XFERCOMPLMSK2         : Boolean := False;
      H_CHHLTDMSK2            : Boolean := False;
      H_AHBERRMSK2            : Boolean := False;
      H_STALLMSK2             : Boolean := False;
      H_NAKMSK2               : Boolean := False;
      H_ACKMSK2               : Boolean := False;
      H_NYETMSK2              : Boolean := False;
      H_XACTERRMSK2           : Boolean := False;
      H_BBLERRMSK2            : Boolean := False;
      H_FRMOVRUNMSK2          : Boolean := False;
      H_DATATGLERRMSK2        : Boolean := False;
      H_BNAINTRMSK2           : Boolean := False;
      --  unspecified
      Reserved_12_12          : ESP32S3_Registers.Bit := 16#0#;
      H_DESC_LST_ROLLINTRMSK2 : Boolean := False;
      --  unspecified
      Reserved_14_31          : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINTMSK2_Register use record
      H_XFERCOMPLMSK2         at 0 range 0 .. 0;
      H_CHHLTDMSK2            at 0 range 1 .. 1;
      H_AHBERRMSK2            at 0 range 2 .. 2;
      H_STALLMSK2             at 0 range 3 .. 3;
      H_NAKMSK2               at 0 range 4 .. 4;
      H_ACKMSK2               at 0 range 5 .. 5;
      H_NYETMSK2              at 0 range 6 .. 6;
      H_XACTERRMSK2           at 0 range 7 .. 7;
      H_BBLERRMSK2            at 0 range 8 .. 8;
      H_FRMOVRUNMSK2          at 0 range 9 .. 9;
      H_DATATGLERRMSK2        at 0 range 10 .. 10;
      H_BNAINTRMSK2           at 0 range 11 .. 11;
      Reserved_12_12          at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTRMSK2 at 0 range 13 .. 13;
      Reserved_14_31          at 0 range 14 .. 31;
   end record;

   subtype HCTSIZ2_H_XFERSIZE2_Field is ESP32S3_Registers.UInt19;
   subtype HCTSIZ2_H_PKTCNT2_Field is ESP32S3_Registers.UInt10;
   subtype HCTSIZ2_H_PID2_Field is ESP32S3_Registers.UInt2;

   type HCTSIZ2_Register is record
      H_XFERSIZE2 : HCTSIZ2_H_XFERSIZE2_Field := 16#0#;
      H_PKTCNT2   : HCTSIZ2_H_PKTCNT2_Field := 16#0#;
      H_PID2      : HCTSIZ2_H_PID2_Field := 16#0#;
      H_DOPNG2    : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCTSIZ2_Register use record
      H_XFERSIZE2 at 0 range 0 .. 18;
      H_PKTCNT2   at 0 range 19 .. 28;
      H_PID2      at 0 range 29 .. 30;
      H_DOPNG2    at 0 range 31 .. 31;
   end record;

   subtype HCCHAR3_H_MPS3_Field is ESP32S3_Registers.UInt11;
   subtype HCCHAR3_H_EPNUM3_Field is ESP32S3_Registers.UInt4;
   subtype HCCHAR3_H_EPTYPE3_Field is ESP32S3_Registers.UInt2;
   subtype HCCHAR3_H_DEVADDR3_Field is ESP32S3_Registers.UInt7;

   type HCCHAR3_Register is record
      H_MPS3         : HCCHAR3_H_MPS3_Field := 16#0#;
      H_EPNUM3       : HCCHAR3_H_EPNUM3_Field := 16#0#;
      H_EPDIR3       : Boolean := False;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      H_LSPDDEV3     : Boolean := False;
      H_EPTYPE3      : HCCHAR3_H_EPTYPE3_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      H_EC3          : Boolean := False;
      H_DEVADDR3     : HCCHAR3_H_DEVADDR3_Field := 16#0#;
      H_ODDFRM3      : Boolean := False;
      H_CHDIS3       : Boolean := False;
      H_CHENA3       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCCHAR3_Register use record
      H_MPS3         at 0 range 0 .. 10;
      H_EPNUM3       at 0 range 11 .. 14;
      H_EPDIR3       at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      H_LSPDDEV3     at 0 range 17 .. 17;
      H_EPTYPE3      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      H_EC3          at 0 range 21 .. 21;
      H_DEVADDR3     at 0 range 22 .. 28;
      H_ODDFRM3      at 0 range 29 .. 29;
      H_CHDIS3       at 0 range 30 .. 30;
      H_CHENA3       at 0 range 31 .. 31;
   end record;

   type HCINT3_Register is record
      H_XFERCOMPL3         : Boolean := False;
      H_CHHLTD3            : Boolean := False;
      H_AHBERR3            : Boolean := False;
      H_STALL3             : Boolean := False;
      H_NACK3              : Boolean := False;
      H_ACK3               : Boolean := False;
      H_NYET3              : Boolean := False;
      H_XACTERR3           : Boolean := False;
      H_BBLERR3            : Boolean := False;
      H_FRMOVRUN3          : Boolean := False;
      H_DATATGLERR3        : Boolean := False;
      H_BNAINTR3           : Boolean := False;
      H_XCS_XACT_ERR3      : Boolean := False;
      H_DESC_LST_ROLLINTR3 : Boolean := False;
      --  unspecified
      Reserved_14_31       : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINT3_Register use record
      H_XFERCOMPL3         at 0 range 0 .. 0;
      H_CHHLTD3            at 0 range 1 .. 1;
      H_AHBERR3            at 0 range 2 .. 2;
      H_STALL3             at 0 range 3 .. 3;
      H_NACK3              at 0 range 4 .. 4;
      H_ACK3               at 0 range 5 .. 5;
      H_NYET3              at 0 range 6 .. 6;
      H_XACTERR3           at 0 range 7 .. 7;
      H_BBLERR3            at 0 range 8 .. 8;
      H_FRMOVRUN3          at 0 range 9 .. 9;
      H_DATATGLERR3        at 0 range 10 .. 10;
      H_BNAINTR3           at 0 range 11 .. 11;
      H_XCS_XACT_ERR3      at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTR3 at 0 range 13 .. 13;
      Reserved_14_31       at 0 range 14 .. 31;
   end record;

   type HCINTMSK3_Register is record
      H_XFERCOMPLMSK3         : Boolean := False;
      H_CHHLTDMSK3            : Boolean := False;
      H_AHBERRMSK3            : Boolean := False;
      H_STALLMSK3             : Boolean := False;
      H_NAKMSK3               : Boolean := False;
      H_ACKMSK3               : Boolean := False;
      H_NYETMSK3              : Boolean := False;
      H_XACTERRMSK3           : Boolean := False;
      H_BBLERRMSK3            : Boolean := False;
      H_FRMOVRUNMSK3          : Boolean := False;
      H_DATATGLERRMSK3        : Boolean := False;
      H_BNAINTRMSK3           : Boolean := False;
      --  unspecified
      Reserved_12_12          : ESP32S3_Registers.Bit := 16#0#;
      H_DESC_LST_ROLLINTRMSK3 : Boolean := False;
      --  unspecified
      Reserved_14_31          : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINTMSK3_Register use record
      H_XFERCOMPLMSK3         at 0 range 0 .. 0;
      H_CHHLTDMSK3            at 0 range 1 .. 1;
      H_AHBERRMSK3            at 0 range 2 .. 2;
      H_STALLMSK3             at 0 range 3 .. 3;
      H_NAKMSK3               at 0 range 4 .. 4;
      H_ACKMSK3               at 0 range 5 .. 5;
      H_NYETMSK3              at 0 range 6 .. 6;
      H_XACTERRMSK3           at 0 range 7 .. 7;
      H_BBLERRMSK3            at 0 range 8 .. 8;
      H_FRMOVRUNMSK3          at 0 range 9 .. 9;
      H_DATATGLERRMSK3        at 0 range 10 .. 10;
      H_BNAINTRMSK3           at 0 range 11 .. 11;
      Reserved_12_12          at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTRMSK3 at 0 range 13 .. 13;
      Reserved_14_31          at 0 range 14 .. 31;
   end record;

   subtype HCTSIZ3_H_XFERSIZE3_Field is ESP32S3_Registers.UInt19;
   subtype HCTSIZ3_H_PKTCNT3_Field is ESP32S3_Registers.UInt10;
   subtype HCTSIZ3_H_PID3_Field is ESP32S3_Registers.UInt2;

   type HCTSIZ3_Register is record
      H_XFERSIZE3 : HCTSIZ3_H_XFERSIZE3_Field := 16#0#;
      H_PKTCNT3   : HCTSIZ3_H_PKTCNT3_Field := 16#0#;
      H_PID3      : HCTSIZ3_H_PID3_Field := 16#0#;
      H_DOPNG3    : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCTSIZ3_Register use record
      H_XFERSIZE3 at 0 range 0 .. 18;
      H_PKTCNT3   at 0 range 19 .. 28;
      H_PID3      at 0 range 29 .. 30;
      H_DOPNG3    at 0 range 31 .. 31;
   end record;

   subtype HCCHAR4_H_MPS4_Field is ESP32S3_Registers.UInt11;
   subtype HCCHAR4_H_EPNUM4_Field is ESP32S3_Registers.UInt4;
   subtype HCCHAR4_H_EPTYPE4_Field is ESP32S3_Registers.UInt2;
   subtype HCCHAR4_H_DEVADDR4_Field is ESP32S3_Registers.UInt7;

   type HCCHAR4_Register is record
      H_MPS4         : HCCHAR4_H_MPS4_Field := 16#0#;
      H_EPNUM4       : HCCHAR4_H_EPNUM4_Field := 16#0#;
      H_EPDIR4       : Boolean := False;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      H_LSPDDEV4     : Boolean := False;
      H_EPTYPE4      : HCCHAR4_H_EPTYPE4_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      H_EC4          : Boolean := False;
      H_DEVADDR4     : HCCHAR4_H_DEVADDR4_Field := 16#0#;
      H_ODDFRM4      : Boolean := False;
      H_CHDIS4       : Boolean := False;
      H_CHENA4       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCCHAR4_Register use record
      H_MPS4         at 0 range 0 .. 10;
      H_EPNUM4       at 0 range 11 .. 14;
      H_EPDIR4       at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      H_LSPDDEV4     at 0 range 17 .. 17;
      H_EPTYPE4      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      H_EC4          at 0 range 21 .. 21;
      H_DEVADDR4     at 0 range 22 .. 28;
      H_ODDFRM4      at 0 range 29 .. 29;
      H_CHDIS4       at 0 range 30 .. 30;
      H_CHENA4       at 0 range 31 .. 31;
   end record;

   type HCINT4_Register is record
      H_XFERCOMPL4         : Boolean := False;
      H_CHHLTD4            : Boolean := False;
      H_AHBERR4            : Boolean := False;
      H_STALL4             : Boolean := False;
      H_NACK4              : Boolean := False;
      H_ACK4               : Boolean := False;
      H_NYET4              : Boolean := False;
      H_XACTERR4           : Boolean := False;
      H_BBLERR4            : Boolean := False;
      H_FRMOVRUN4          : Boolean := False;
      H_DATATGLERR4        : Boolean := False;
      H_BNAINTR4           : Boolean := False;
      H_XCS_XACT_ERR4      : Boolean := False;
      H_DESC_LST_ROLLINTR4 : Boolean := False;
      --  unspecified
      Reserved_14_31       : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINT4_Register use record
      H_XFERCOMPL4         at 0 range 0 .. 0;
      H_CHHLTD4            at 0 range 1 .. 1;
      H_AHBERR4            at 0 range 2 .. 2;
      H_STALL4             at 0 range 3 .. 3;
      H_NACK4              at 0 range 4 .. 4;
      H_ACK4               at 0 range 5 .. 5;
      H_NYET4              at 0 range 6 .. 6;
      H_XACTERR4           at 0 range 7 .. 7;
      H_BBLERR4            at 0 range 8 .. 8;
      H_FRMOVRUN4          at 0 range 9 .. 9;
      H_DATATGLERR4        at 0 range 10 .. 10;
      H_BNAINTR4           at 0 range 11 .. 11;
      H_XCS_XACT_ERR4      at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTR4 at 0 range 13 .. 13;
      Reserved_14_31       at 0 range 14 .. 31;
   end record;

   type HCINTMSK4_Register is record
      H_XFERCOMPLMSK4         : Boolean := False;
      H_CHHLTDMSK4            : Boolean := False;
      H_AHBERRMSK4            : Boolean := False;
      H_STALLMSK4             : Boolean := False;
      H_NAKMSK4               : Boolean := False;
      H_ACKMSK4               : Boolean := False;
      H_NYETMSK4              : Boolean := False;
      H_XACTERRMSK4           : Boolean := False;
      H_BBLERRMSK4            : Boolean := False;
      H_FRMOVRUNMSK4          : Boolean := False;
      H_DATATGLERRMSK4        : Boolean := False;
      H_BNAINTRMSK4           : Boolean := False;
      --  unspecified
      Reserved_12_12          : ESP32S3_Registers.Bit := 16#0#;
      H_DESC_LST_ROLLINTRMSK4 : Boolean := False;
      --  unspecified
      Reserved_14_31          : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINTMSK4_Register use record
      H_XFERCOMPLMSK4         at 0 range 0 .. 0;
      H_CHHLTDMSK4            at 0 range 1 .. 1;
      H_AHBERRMSK4            at 0 range 2 .. 2;
      H_STALLMSK4             at 0 range 3 .. 3;
      H_NAKMSK4               at 0 range 4 .. 4;
      H_ACKMSK4               at 0 range 5 .. 5;
      H_NYETMSK4              at 0 range 6 .. 6;
      H_XACTERRMSK4           at 0 range 7 .. 7;
      H_BBLERRMSK4            at 0 range 8 .. 8;
      H_FRMOVRUNMSK4          at 0 range 9 .. 9;
      H_DATATGLERRMSK4        at 0 range 10 .. 10;
      H_BNAINTRMSK4           at 0 range 11 .. 11;
      Reserved_12_12          at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTRMSK4 at 0 range 13 .. 13;
      Reserved_14_31          at 0 range 14 .. 31;
   end record;

   subtype HCTSIZ4_H_XFERSIZE4_Field is ESP32S3_Registers.UInt19;
   subtype HCTSIZ4_H_PKTCNT4_Field is ESP32S3_Registers.UInt10;
   subtype HCTSIZ4_H_PID4_Field is ESP32S3_Registers.UInt2;

   type HCTSIZ4_Register is record
      H_XFERSIZE4 : HCTSIZ4_H_XFERSIZE4_Field := 16#0#;
      H_PKTCNT4   : HCTSIZ4_H_PKTCNT4_Field := 16#0#;
      H_PID4      : HCTSIZ4_H_PID4_Field := 16#0#;
      H_DOPNG4    : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCTSIZ4_Register use record
      H_XFERSIZE4 at 0 range 0 .. 18;
      H_PKTCNT4   at 0 range 19 .. 28;
      H_PID4      at 0 range 29 .. 30;
      H_DOPNG4    at 0 range 31 .. 31;
   end record;

   subtype HCCHAR5_H_MPS5_Field is ESP32S3_Registers.UInt11;
   subtype HCCHAR5_H_EPNUM5_Field is ESP32S3_Registers.UInt4;
   subtype HCCHAR5_H_EPTYPE5_Field is ESP32S3_Registers.UInt2;
   subtype HCCHAR5_H_DEVADDR5_Field is ESP32S3_Registers.UInt7;

   type HCCHAR5_Register is record
      H_MPS5         : HCCHAR5_H_MPS5_Field := 16#0#;
      H_EPNUM5       : HCCHAR5_H_EPNUM5_Field := 16#0#;
      H_EPDIR5       : Boolean := False;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      H_LSPDDEV5     : Boolean := False;
      H_EPTYPE5      : HCCHAR5_H_EPTYPE5_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      H_EC5          : Boolean := False;
      H_DEVADDR5     : HCCHAR5_H_DEVADDR5_Field := 16#0#;
      H_ODDFRM5      : Boolean := False;
      H_CHDIS5       : Boolean := False;
      H_CHENA5       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCCHAR5_Register use record
      H_MPS5         at 0 range 0 .. 10;
      H_EPNUM5       at 0 range 11 .. 14;
      H_EPDIR5       at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      H_LSPDDEV5     at 0 range 17 .. 17;
      H_EPTYPE5      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      H_EC5          at 0 range 21 .. 21;
      H_DEVADDR5     at 0 range 22 .. 28;
      H_ODDFRM5      at 0 range 29 .. 29;
      H_CHDIS5       at 0 range 30 .. 30;
      H_CHENA5       at 0 range 31 .. 31;
   end record;

   type HCINT5_Register is record
      H_XFERCOMPL5         : Boolean := False;
      H_CHHLTD5            : Boolean := False;
      H_AHBERR5            : Boolean := False;
      H_STALL5             : Boolean := False;
      H_NACK5              : Boolean := False;
      H_ACK5               : Boolean := False;
      H_NYET5              : Boolean := False;
      H_XACTERR5           : Boolean := False;
      H_BBLERR5            : Boolean := False;
      H_FRMOVRUN5          : Boolean := False;
      H_DATATGLERR5        : Boolean := False;
      H_BNAINTR5           : Boolean := False;
      H_XCS_XACT_ERR5      : Boolean := False;
      H_DESC_LST_ROLLINTR5 : Boolean := False;
      --  unspecified
      Reserved_14_31       : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINT5_Register use record
      H_XFERCOMPL5         at 0 range 0 .. 0;
      H_CHHLTD5            at 0 range 1 .. 1;
      H_AHBERR5            at 0 range 2 .. 2;
      H_STALL5             at 0 range 3 .. 3;
      H_NACK5              at 0 range 4 .. 4;
      H_ACK5               at 0 range 5 .. 5;
      H_NYET5              at 0 range 6 .. 6;
      H_XACTERR5           at 0 range 7 .. 7;
      H_BBLERR5            at 0 range 8 .. 8;
      H_FRMOVRUN5          at 0 range 9 .. 9;
      H_DATATGLERR5        at 0 range 10 .. 10;
      H_BNAINTR5           at 0 range 11 .. 11;
      H_XCS_XACT_ERR5      at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTR5 at 0 range 13 .. 13;
      Reserved_14_31       at 0 range 14 .. 31;
   end record;

   type HCINTMSK5_Register is record
      H_XFERCOMPLMSK5         : Boolean := False;
      H_CHHLTDMSK5            : Boolean := False;
      H_AHBERRMSK5            : Boolean := False;
      H_STALLMSK5             : Boolean := False;
      H_NAKMSK5               : Boolean := False;
      H_ACKMSK5               : Boolean := False;
      H_NYETMSK5              : Boolean := False;
      H_XACTERRMSK5           : Boolean := False;
      H_BBLERRMSK5            : Boolean := False;
      H_FRMOVRUNMSK5          : Boolean := False;
      H_DATATGLERRMSK5        : Boolean := False;
      H_BNAINTRMSK5           : Boolean := False;
      --  unspecified
      Reserved_12_12          : ESP32S3_Registers.Bit := 16#0#;
      H_DESC_LST_ROLLINTRMSK5 : Boolean := False;
      --  unspecified
      Reserved_14_31          : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINTMSK5_Register use record
      H_XFERCOMPLMSK5         at 0 range 0 .. 0;
      H_CHHLTDMSK5            at 0 range 1 .. 1;
      H_AHBERRMSK5            at 0 range 2 .. 2;
      H_STALLMSK5             at 0 range 3 .. 3;
      H_NAKMSK5               at 0 range 4 .. 4;
      H_ACKMSK5               at 0 range 5 .. 5;
      H_NYETMSK5              at 0 range 6 .. 6;
      H_XACTERRMSK5           at 0 range 7 .. 7;
      H_BBLERRMSK5            at 0 range 8 .. 8;
      H_FRMOVRUNMSK5          at 0 range 9 .. 9;
      H_DATATGLERRMSK5        at 0 range 10 .. 10;
      H_BNAINTRMSK5           at 0 range 11 .. 11;
      Reserved_12_12          at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTRMSK5 at 0 range 13 .. 13;
      Reserved_14_31          at 0 range 14 .. 31;
   end record;

   subtype HCTSIZ5_H_XFERSIZE5_Field is ESP32S3_Registers.UInt19;
   subtype HCTSIZ5_H_PKTCNT5_Field is ESP32S3_Registers.UInt10;
   subtype HCTSIZ5_H_PID5_Field is ESP32S3_Registers.UInt2;

   type HCTSIZ5_Register is record
      H_XFERSIZE5 : HCTSIZ5_H_XFERSIZE5_Field := 16#0#;
      H_PKTCNT5   : HCTSIZ5_H_PKTCNT5_Field := 16#0#;
      H_PID5      : HCTSIZ5_H_PID5_Field := 16#0#;
      H_DOPNG5    : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCTSIZ5_Register use record
      H_XFERSIZE5 at 0 range 0 .. 18;
      H_PKTCNT5   at 0 range 19 .. 28;
      H_PID5      at 0 range 29 .. 30;
      H_DOPNG5    at 0 range 31 .. 31;
   end record;

   subtype HCCHAR6_H_MPS6_Field is ESP32S3_Registers.UInt11;
   subtype HCCHAR6_H_EPNUM6_Field is ESP32S3_Registers.UInt4;
   subtype HCCHAR6_H_EPTYPE6_Field is ESP32S3_Registers.UInt2;
   subtype HCCHAR6_H_DEVADDR6_Field is ESP32S3_Registers.UInt7;

   type HCCHAR6_Register is record
      H_MPS6         : HCCHAR6_H_MPS6_Field := 16#0#;
      H_EPNUM6       : HCCHAR6_H_EPNUM6_Field := 16#0#;
      H_EPDIR6       : Boolean := False;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      H_LSPDDEV6     : Boolean := False;
      H_EPTYPE6      : HCCHAR6_H_EPTYPE6_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      H_EC6          : Boolean := False;
      H_DEVADDR6     : HCCHAR6_H_DEVADDR6_Field := 16#0#;
      H_ODDFRM6      : Boolean := False;
      H_CHDIS6       : Boolean := False;
      H_CHENA6       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCCHAR6_Register use record
      H_MPS6         at 0 range 0 .. 10;
      H_EPNUM6       at 0 range 11 .. 14;
      H_EPDIR6       at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      H_LSPDDEV6     at 0 range 17 .. 17;
      H_EPTYPE6      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      H_EC6          at 0 range 21 .. 21;
      H_DEVADDR6     at 0 range 22 .. 28;
      H_ODDFRM6      at 0 range 29 .. 29;
      H_CHDIS6       at 0 range 30 .. 30;
      H_CHENA6       at 0 range 31 .. 31;
   end record;

   type HCINT6_Register is record
      H_XFERCOMPL6         : Boolean := False;
      H_CHHLTD6            : Boolean := False;
      H_AHBERR6            : Boolean := False;
      H_STALL6             : Boolean := False;
      H_NACK6              : Boolean := False;
      H_ACK6               : Boolean := False;
      H_NYET6              : Boolean := False;
      H_XACTERR6           : Boolean := False;
      H_BBLERR6            : Boolean := False;
      H_FRMOVRUN6          : Boolean := False;
      H_DATATGLERR6        : Boolean := False;
      H_BNAINTR6           : Boolean := False;
      H_XCS_XACT_ERR6      : Boolean := False;
      H_DESC_LST_ROLLINTR6 : Boolean := False;
      --  unspecified
      Reserved_14_31       : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINT6_Register use record
      H_XFERCOMPL6         at 0 range 0 .. 0;
      H_CHHLTD6            at 0 range 1 .. 1;
      H_AHBERR6            at 0 range 2 .. 2;
      H_STALL6             at 0 range 3 .. 3;
      H_NACK6              at 0 range 4 .. 4;
      H_ACK6               at 0 range 5 .. 5;
      H_NYET6              at 0 range 6 .. 6;
      H_XACTERR6           at 0 range 7 .. 7;
      H_BBLERR6            at 0 range 8 .. 8;
      H_FRMOVRUN6          at 0 range 9 .. 9;
      H_DATATGLERR6        at 0 range 10 .. 10;
      H_BNAINTR6           at 0 range 11 .. 11;
      H_XCS_XACT_ERR6      at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTR6 at 0 range 13 .. 13;
      Reserved_14_31       at 0 range 14 .. 31;
   end record;

   type HCINTMSK6_Register is record
      H_XFERCOMPLMSK6         : Boolean := False;
      H_CHHLTDMSK6            : Boolean := False;
      H_AHBERRMSK6            : Boolean := False;
      H_STALLMSK6             : Boolean := False;
      H_NAKMSK6               : Boolean := False;
      H_ACKMSK6               : Boolean := False;
      H_NYETMSK6              : Boolean := False;
      H_XACTERRMSK6           : Boolean := False;
      H_BBLERRMSK6            : Boolean := False;
      H_FRMOVRUNMSK6          : Boolean := False;
      H_DATATGLERRMSK6        : Boolean := False;
      H_BNAINTRMSK6           : Boolean := False;
      --  unspecified
      Reserved_12_12          : ESP32S3_Registers.Bit := 16#0#;
      H_DESC_LST_ROLLINTRMSK6 : Boolean := False;
      --  unspecified
      Reserved_14_31          : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINTMSK6_Register use record
      H_XFERCOMPLMSK6         at 0 range 0 .. 0;
      H_CHHLTDMSK6            at 0 range 1 .. 1;
      H_AHBERRMSK6            at 0 range 2 .. 2;
      H_STALLMSK6             at 0 range 3 .. 3;
      H_NAKMSK6               at 0 range 4 .. 4;
      H_ACKMSK6               at 0 range 5 .. 5;
      H_NYETMSK6              at 0 range 6 .. 6;
      H_XACTERRMSK6           at 0 range 7 .. 7;
      H_BBLERRMSK6            at 0 range 8 .. 8;
      H_FRMOVRUNMSK6          at 0 range 9 .. 9;
      H_DATATGLERRMSK6        at 0 range 10 .. 10;
      H_BNAINTRMSK6           at 0 range 11 .. 11;
      Reserved_12_12          at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTRMSK6 at 0 range 13 .. 13;
      Reserved_14_31          at 0 range 14 .. 31;
   end record;

   subtype HCTSIZ6_H_XFERSIZE6_Field is ESP32S3_Registers.UInt19;
   subtype HCTSIZ6_H_PKTCNT6_Field is ESP32S3_Registers.UInt10;
   subtype HCTSIZ6_H_PID6_Field is ESP32S3_Registers.UInt2;

   type HCTSIZ6_Register is record
      H_XFERSIZE6 : HCTSIZ6_H_XFERSIZE6_Field := 16#0#;
      H_PKTCNT6   : HCTSIZ6_H_PKTCNT6_Field := 16#0#;
      H_PID6      : HCTSIZ6_H_PID6_Field := 16#0#;
      H_DOPNG6    : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCTSIZ6_Register use record
      H_XFERSIZE6 at 0 range 0 .. 18;
      H_PKTCNT6   at 0 range 19 .. 28;
      H_PID6      at 0 range 29 .. 30;
      H_DOPNG6    at 0 range 31 .. 31;
   end record;

   subtype HCCHAR7_H_MPS7_Field is ESP32S3_Registers.UInt11;
   subtype HCCHAR7_H_EPNUM7_Field is ESP32S3_Registers.UInt4;
   subtype HCCHAR7_H_EPTYPE7_Field is ESP32S3_Registers.UInt2;
   subtype HCCHAR7_H_DEVADDR7_Field is ESP32S3_Registers.UInt7;

   type HCCHAR7_Register is record
      H_MPS7         : HCCHAR7_H_MPS7_Field := 16#0#;
      H_EPNUM7       : HCCHAR7_H_EPNUM7_Field := 16#0#;
      H_EPDIR7       : Boolean := False;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      H_LSPDDEV7     : Boolean := False;
      H_EPTYPE7      : HCCHAR7_H_EPTYPE7_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      H_EC7          : Boolean := False;
      H_DEVADDR7     : HCCHAR7_H_DEVADDR7_Field := 16#0#;
      H_ODDFRM7      : Boolean := False;
      H_CHDIS7       : Boolean := False;
      H_CHENA7       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCCHAR7_Register use record
      H_MPS7         at 0 range 0 .. 10;
      H_EPNUM7       at 0 range 11 .. 14;
      H_EPDIR7       at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      H_LSPDDEV7     at 0 range 17 .. 17;
      H_EPTYPE7      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      H_EC7          at 0 range 21 .. 21;
      H_DEVADDR7     at 0 range 22 .. 28;
      H_ODDFRM7      at 0 range 29 .. 29;
      H_CHDIS7       at 0 range 30 .. 30;
      H_CHENA7       at 0 range 31 .. 31;
   end record;

   type HCINT7_Register is record
      H_XFERCOMPL7         : Boolean := False;
      H_CHHLTD7            : Boolean := False;
      H_AHBERR7            : Boolean := False;
      H_STALL7             : Boolean := False;
      H_NACK7              : Boolean := False;
      H_ACK7               : Boolean := False;
      H_NYET7              : Boolean := False;
      H_XACTERR7           : Boolean := False;
      H_BBLERR7            : Boolean := False;
      H_FRMOVRUN7          : Boolean := False;
      H_DATATGLERR7        : Boolean := False;
      H_BNAINTR7           : Boolean := False;
      H_XCS_XACT_ERR7      : Boolean := False;
      H_DESC_LST_ROLLINTR7 : Boolean := False;
      --  unspecified
      Reserved_14_31       : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINT7_Register use record
      H_XFERCOMPL7         at 0 range 0 .. 0;
      H_CHHLTD7            at 0 range 1 .. 1;
      H_AHBERR7            at 0 range 2 .. 2;
      H_STALL7             at 0 range 3 .. 3;
      H_NACK7              at 0 range 4 .. 4;
      H_ACK7               at 0 range 5 .. 5;
      H_NYET7              at 0 range 6 .. 6;
      H_XACTERR7           at 0 range 7 .. 7;
      H_BBLERR7            at 0 range 8 .. 8;
      H_FRMOVRUN7          at 0 range 9 .. 9;
      H_DATATGLERR7        at 0 range 10 .. 10;
      H_BNAINTR7           at 0 range 11 .. 11;
      H_XCS_XACT_ERR7      at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTR7 at 0 range 13 .. 13;
      Reserved_14_31       at 0 range 14 .. 31;
   end record;

   type HCINTMSK7_Register is record
      H_XFERCOMPLMSK7         : Boolean := False;
      H_CHHLTDMSK7            : Boolean := False;
      H_AHBERRMSK7            : Boolean := False;
      H_STALLMSK7             : Boolean := False;
      H_NAKMSK7               : Boolean := False;
      H_ACKMSK7               : Boolean := False;
      H_NYETMSK7              : Boolean := False;
      H_XACTERRMSK7           : Boolean := False;
      H_BBLERRMSK7            : Boolean := False;
      H_FRMOVRUNMSK7          : Boolean := False;
      H_DATATGLERRMSK7        : Boolean := False;
      H_BNAINTRMSK7           : Boolean := False;
      --  unspecified
      Reserved_12_12          : ESP32S3_Registers.Bit := 16#0#;
      H_DESC_LST_ROLLINTRMSK7 : Boolean := False;
      --  unspecified
      Reserved_14_31          : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCINTMSK7_Register use record
      H_XFERCOMPLMSK7         at 0 range 0 .. 0;
      H_CHHLTDMSK7            at 0 range 1 .. 1;
      H_AHBERRMSK7            at 0 range 2 .. 2;
      H_STALLMSK7             at 0 range 3 .. 3;
      H_NAKMSK7               at 0 range 4 .. 4;
      H_ACKMSK7               at 0 range 5 .. 5;
      H_NYETMSK7              at 0 range 6 .. 6;
      H_XACTERRMSK7           at 0 range 7 .. 7;
      H_BBLERRMSK7            at 0 range 8 .. 8;
      H_FRMOVRUNMSK7          at 0 range 9 .. 9;
      H_DATATGLERRMSK7        at 0 range 10 .. 10;
      H_BNAINTRMSK7           at 0 range 11 .. 11;
      Reserved_12_12          at 0 range 12 .. 12;
      H_DESC_LST_ROLLINTRMSK7 at 0 range 13 .. 13;
      Reserved_14_31          at 0 range 14 .. 31;
   end record;

   subtype HCTSIZ7_H_XFERSIZE7_Field is ESP32S3_Registers.UInt19;
   subtype HCTSIZ7_H_PKTCNT7_Field is ESP32S3_Registers.UInt10;
   subtype HCTSIZ7_H_PID7_Field is ESP32S3_Registers.UInt2;

   type HCTSIZ7_Register is record
      H_XFERSIZE7 : HCTSIZ7_H_XFERSIZE7_Field := 16#0#;
      H_PKTCNT7   : HCTSIZ7_H_PKTCNT7_Field := 16#0#;
      H_PID7      : HCTSIZ7_H_PID7_Field := 16#0#;
      H_DOPNG7    : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCTSIZ7_Register use record
      H_XFERSIZE7 at 0 range 0 .. 18;
      H_PKTCNT7   at 0 range 19 .. 28;
      H_PID7      at 0 range 29 .. 30;
      H_DOPNG7    at 0 range 31 .. 31;
   end record;

   subtype DCFG_DEVADDR_Field is ESP32S3_Registers.UInt7;
   subtype DCFG_PERFRLINT_Field is ESP32S3_Registers.UInt2;
   subtype DCFG_EPMISCNT_Field is ESP32S3_Registers.UInt5;
   subtype DCFG_PERSCHINTVL_Field is ESP32S3_Registers.UInt2;
   subtype DCFG_RESVALID_Field is ESP32S3_Registers.UInt6;

   type DCFG_Register is record
      --  unspecified
      Reserved_0_1   : ESP32S3_Registers.UInt2 := 16#0#;
      NZSTSOUTHSHK   : Boolean := False;
      ENA32KHZSUSP   : Boolean := False;
      DEVADDR        : DCFG_DEVADDR_Field := 16#0#;
      PERFRLINT      : DCFG_PERFRLINT_Field := 16#0#;
      ENDEVOUTNAK    : Boolean := False;
      XCVRDLY        : Boolean := False;
      ERRATICINTMSK  : Boolean := False;
      --  unspecified
      Reserved_16_17 : ESP32S3_Registers.UInt2 := 16#0#;
      EPMISCNT       : DCFG_EPMISCNT_Field := 16#4#;
      DESCDMA        : Boolean := False;
      PERSCHINTVL    : DCFG_PERSCHINTVL_Field := 16#0#;
      RESVALID       : DCFG_RESVALID_Field := 16#2#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DCFG_Register use record
      Reserved_0_1   at 0 range 0 .. 1;
      NZSTSOUTHSHK   at 0 range 2 .. 2;
      ENA32KHZSUSP   at 0 range 3 .. 3;
      DEVADDR        at 0 range 4 .. 10;
      PERFRLINT      at 0 range 11 .. 12;
      ENDEVOUTNAK    at 0 range 13 .. 13;
      XCVRDLY        at 0 range 14 .. 14;
      ERRATICINTMSK  at 0 range 15 .. 15;
      Reserved_16_17 at 0 range 16 .. 17;
      EPMISCNT       at 0 range 18 .. 22;
      DESCDMA        at 0 range 23 .. 23;
      PERSCHINTVL    at 0 range 24 .. 25;
      RESVALID       at 0 range 26 .. 31;
   end record;

   subtype DCTL_TSTCTL_Field is ESP32S3_Registers.UInt3;
   subtype DCTL_GMC_Field is ESP32S3_Registers.UInt2;

   type DCTL_Register is record
      RMTWKUPSIG          : Boolean := False;
      SFTDISCON           : Boolean := False;
      --  Read-only.
      GNPINNAKSTS         : Boolean := False;
      --  Read-only.
      GOUTNAKSTS          : Boolean := False;
      TSTCTL              : DCTL_TSTCTL_Field := 16#0#;
      --  Write-only.
      SGNPINNAK           : Boolean := False;
      --  Write-only.
      CGNPINNAK           : Boolean := False;
      --  Write-only.
      SGOUTNAK            : Boolean := False;
      --  Write-only.
      CGOUTNAK            : Boolean := False;
      PWRONPRGDONE        : Boolean := False;
      --  unspecified
      Reserved_12_12      : ESP32S3_Registers.Bit := 16#0#;
      GMC                 : DCTL_GMC_Field := 16#1#;
      IGNRFRMNUM          : Boolean := False;
      NAKONBBLE           : Boolean := False;
      ENCOUNTONBNA        : Boolean := False;
      DEEPSLEEPBESLREJECT : Boolean := False;
      --  unspecified
      Reserved_19_31      : ESP32S3_Registers.UInt13 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DCTL_Register use record
      RMTWKUPSIG          at 0 range 0 .. 0;
      SFTDISCON           at 0 range 1 .. 1;
      GNPINNAKSTS         at 0 range 2 .. 2;
      GOUTNAKSTS          at 0 range 3 .. 3;
      TSTCTL              at 0 range 4 .. 6;
      SGNPINNAK           at 0 range 7 .. 7;
      CGNPINNAK           at 0 range 8 .. 8;
      SGOUTNAK            at 0 range 9 .. 9;
      CGOUTNAK            at 0 range 10 .. 10;
      PWRONPRGDONE        at 0 range 11 .. 11;
      Reserved_12_12      at 0 range 12 .. 12;
      GMC                 at 0 range 13 .. 14;
      IGNRFRMNUM          at 0 range 15 .. 15;
      NAKONBBLE           at 0 range 16 .. 16;
      ENCOUNTONBNA        at 0 range 17 .. 17;
      DEEPSLEEPBESLREJECT at 0 range 18 .. 18;
      Reserved_19_31      at 0 range 19 .. 31;
   end record;

   subtype DSTS_ENUMSPD_Field is ESP32S3_Registers.UInt2;
   subtype DSTS_SOFFN_Field is ESP32S3_Registers.UInt14;
   subtype DSTS_DEVLNSTS_Field is ESP32S3_Registers.UInt2;

   type DSTS_Register is record
      --  Read-only.
      SUSPSTS        : Boolean;
      --  Read-only.
      ENUMSPD        : DSTS_ENUMSPD_Field;
      --  Read-only.
      ERRTICERR      : Boolean;
      --  unspecified
      Reserved_4_7   : ESP32S3_Registers.UInt4;
      --  Read-only.
      SOFFN          : DSTS_SOFFN_Field;
      --  Read-only.
      DEVLNSTS       : DSTS_DEVLNSTS_Field;
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DSTS_Register use record
      SUSPSTS        at 0 range 0 .. 0;
      ENUMSPD        at 0 range 1 .. 2;
      ERRTICERR      at 0 range 3 .. 3;
      Reserved_4_7   at 0 range 4 .. 7;
      SOFFN          at 0 range 8 .. 21;
      DEVLNSTS       at 0 range 22 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   type DIEPMSK_Register is record
      DI_XFERCOMPLMSK : Boolean := False;
      DI_EPDISBLDMSK  : Boolean := False;
      DI_AHBERMSK     : Boolean := False;
      TIMEOUTMSK      : Boolean := False;
      INTKNTXFEMPMSK  : Boolean := False;
      INTKNEPMISMSK   : Boolean := False;
      INEPNAKEFFMSK   : Boolean := False;
      --  unspecified
      Reserved_7_7    : ESP32S3_Registers.Bit := 16#0#;
      TXFIFOUNDRNMSK  : Boolean := False;
      BNAININTRMSK    : Boolean := False;
      --  unspecified
      Reserved_10_12  : ESP32S3_Registers.UInt3 := 16#0#;
      DI_NAKMSK       : Boolean := False;
      --  unspecified
      Reserved_14_31  : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPMSK_Register use record
      DI_XFERCOMPLMSK at 0 range 0 .. 0;
      DI_EPDISBLDMSK  at 0 range 1 .. 1;
      DI_AHBERMSK     at 0 range 2 .. 2;
      TIMEOUTMSK      at 0 range 3 .. 3;
      INTKNTXFEMPMSK  at 0 range 4 .. 4;
      INTKNEPMISMSK   at 0 range 5 .. 5;
      INEPNAKEFFMSK   at 0 range 6 .. 6;
      Reserved_7_7    at 0 range 7 .. 7;
      TXFIFOUNDRNMSK  at 0 range 8 .. 8;
      BNAININTRMSK    at 0 range 9 .. 9;
      Reserved_10_12  at 0 range 10 .. 12;
      DI_NAKMSK       at 0 range 13 .. 13;
      Reserved_14_31  at 0 range 14 .. 31;
   end record;

   type DOEPMSK_Register is record
      XFERCOMPLMSK   : Boolean := False;
      EPDISBLDMSK    : Boolean := False;
      AHBERMSK       : Boolean := False;
      SETUPMSK       : Boolean := False;
      OUTTKNEPDISMSK : Boolean := False;
      STSPHSERCVDMSK : Boolean := False;
      BACK2BACKSETUP : Boolean := False;
      --  unspecified
      Reserved_7_7   : ESP32S3_Registers.Bit := 16#0#;
      OUTPKTERRMSK   : Boolean := False;
      BNAOUTINTRMSK  : Boolean := False;
      --  unspecified
      Reserved_10_11 : ESP32S3_Registers.UInt2 := 16#0#;
      BBLEERRMSK     : Boolean := False;
      NAKMSK         : Boolean := False;
      NYETMSK        : Boolean := False;
      --  unspecified
      Reserved_15_31 : ESP32S3_Registers.UInt17 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPMSK_Register use record
      XFERCOMPLMSK   at 0 range 0 .. 0;
      EPDISBLDMSK    at 0 range 1 .. 1;
      AHBERMSK       at 0 range 2 .. 2;
      SETUPMSK       at 0 range 3 .. 3;
      OUTTKNEPDISMSK at 0 range 4 .. 4;
      STSPHSERCVDMSK at 0 range 5 .. 5;
      BACK2BACKSETUP at 0 range 6 .. 6;
      Reserved_7_7   at 0 range 7 .. 7;
      OUTPKTERRMSK   at 0 range 8 .. 8;
      BNAOUTINTRMSK  at 0 range 9 .. 9;
      Reserved_10_11 at 0 range 10 .. 11;
      BBLEERRMSK     at 0 range 12 .. 12;
      NAKMSK         at 0 range 13 .. 13;
      NYETMSK        at 0 range 14 .. 14;
      Reserved_15_31 at 0 range 15 .. 31;
   end record;

   --  DAINT_INEPINT array
   type DAINT_INEPINT_Field_Array is array (0 .. 6) of Boolean
     with Component_Size => 1, Size => 7;

   --  Type definition for DAINT_INEPINT
   type DAINT_INEPINT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  INEPINT as a value
            Val : ESP32S3_Registers.UInt7;
         when True =>
            --  INEPINT as an array
            Arr : DAINT_INEPINT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 7;

   for DAINT_INEPINT_Field use record
      Val at 0 range 0 .. 6;
      Arr at 0 range 0 .. 6;
   end record;

   --  DAINT_OUTEPINT array
   type DAINT_OUTEPINT_Field_Array is array (0 .. 6) of Boolean
     with Component_Size => 1, Size => 7;

   --  Type definition for DAINT_OUTEPINT
   type DAINT_OUTEPINT_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  OUTEPINT as a value
            Val : ESP32S3_Registers.UInt7;
         when True =>
            --  OUTEPINT as an array
            Arr : DAINT_OUTEPINT_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 7;

   for DAINT_OUTEPINT_Field use record
      Val at 0 range 0 .. 6;
      Arr at 0 range 0 .. 6;
   end record;

   type DAINT_Register is record
      --  Read-only.
      INEPINT        : DAINT_INEPINT_Field;
      --  unspecified
      Reserved_7_15  : ESP32S3_Registers.UInt9;
      --  Read-only.
      OUTEPINT       : DAINT_OUTEPINT_Field;
      --  unspecified
      Reserved_23_31 : ESP32S3_Registers.UInt9;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DAINT_Register use record
      INEPINT        at 0 range 0 .. 6;
      Reserved_7_15  at 0 range 7 .. 15;
      OUTEPINT       at 0 range 16 .. 22;
      Reserved_23_31 at 0 range 23 .. 31;
   end record;

   --  DAINTMSK_INEPMSK array
   type DAINTMSK_INEPMSK_Field_Array is array (0 .. 6) of Boolean
     with Component_Size => 1, Size => 7;

   --  Type definition for DAINTMSK_INEPMSK
   type DAINTMSK_INEPMSK_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  INEPMSK as a value
            Val : ESP32S3_Registers.UInt7;
         when True =>
            --  INEPMSK as an array
            Arr : DAINTMSK_INEPMSK_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 7;

   for DAINTMSK_INEPMSK_Field use record
      Val at 0 range 0 .. 6;
      Arr at 0 range 0 .. 6;
   end record;

   --  DAINTMSK_OUTEPMSK array
   type DAINTMSK_OUTEPMSK_Field_Array is array (0 .. 6) of Boolean
     with Component_Size => 1, Size => 7;

   --  Type definition for DAINTMSK_OUTEPMSK
   type DAINTMSK_OUTEPMSK_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  OUTEPMSK as a value
            Val : ESP32S3_Registers.UInt7;
         when True =>
            --  OUTEPMSK as an array
            Arr : DAINTMSK_OUTEPMSK_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 7;

   for DAINTMSK_OUTEPMSK_Field use record
      Val at 0 range 0 .. 6;
      Arr at 0 range 0 .. 6;
   end record;

   type DAINTMSK_Register is record
      INEPMSK        : DAINTMSK_INEPMSK_Field :=
                        (As_Array => False, Val => 16#0#);
      --  unspecified
      Reserved_7_15  : ESP32S3_Registers.UInt9 := 16#0#;
      OUTEPMSK       : DAINTMSK_OUTEPMSK_Field :=
                        (As_Array => False, Val => 16#0#);
      --  unspecified
      Reserved_23_31 : ESP32S3_Registers.UInt9 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DAINTMSK_Register use record
      INEPMSK        at 0 range 0 .. 6;
      Reserved_7_15  at 0 range 7 .. 15;
      OUTEPMSK       at 0 range 16 .. 22;
      Reserved_23_31 at 0 range 23 .. 31;
   end record;

   subtype DVBUSDIS_DVBUSDIS_Field is ESP32S3_Registers.UInt16;

   type DVBUSDIS_Register is record
      DVBUSDIS       : DVBUSDIS_DVBUSDIS_Field := 16#17D7#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DVBUSDIS_Register use record
      DVBUSDIS       at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype DVBUSPULSE_DVBUSPULSE_Field is ESP32S3_Registers.UInt12;

   type DVBUSPULSE_Register is record
      DVBUSPULSE     : DVBUSPULSE_DVBUSPULSE_Field := 16#5B8#;
      --  unspecified
      Reserved_12_31 : ESP32S3_Registers.UInt20 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DVBUSPULSE_Register use record
      DVBUSPULSE     at 0 range 0 .. 11;
      Reserved_12_31 at 0 range 12 .. 31;
   end record;

   subtype DTHRCTL_TXTHRLEN_Field is ESP32S3_Registers.UInt9;
   subtype DTHRCTL_AHBTHRRATIO_Field is ESP32S3_Registers.UInt2;
   subtype DTHRCTL_RXTHRLEN_Field is ESP32S3_Registers.UInt9;

   type DTHRCTL_Register is record
      NONISOTHREN    : Boolean := False;
      ISOTHREN       : Boolean := False;
      TXTHRLEN       : DTHRCTL_TXTHRLEN_Field := 16#8#;
      AHBTHRRATIO    : DTHRCTL_AHBTHRRATIO_Field := 16#0#;
      --  unspecified
      Reserved_13_15 : ESP32S3_Registers.UInt3 := 16#0#;
      RXTHREN        : Boolean := False;
      RXTHRLEN       : DTHRCTL_RXTHRLEN_Field := 16#1#;
      --  unspecified
      Reserved_26_26 : ESP32S3_Registers.Bit := 16#0#;
      ARBPRKEN       : Boolean := True;
      --  unspecified
      Reserved_28_31 : ESP32S3_Registers.UInt4 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DTHRCTL_Register use record
      NONISOTHREN    at 0 range 0 .. 0;
      ISOTHREN       at 0 range 1 .. 1;
      TXTHRLEN       at 0 range 2 .. 10;
      AHBTHRRATIO    at 0 range 11 .. 12;
      Reserved_13_15 at 0 range 13 .. 15;
      RXTHREN        at 0 range 16 .. 16;
      RXTHRLEN       at 0 range 17 .. 25;
      Reserved_26_26 at 0 range 26 .. 26;
      ARBPRKEN       at 0 range 27 .. 27;
      Reserved_28_31 at 0 range 28 .. 31;
   end record;

   subtype DIEPEMPMSK_D_INEPTXFEMPMSK_Field is ESP32S3_Registers.UInt16;

   type DIEPEMPMSK_Register is record
      D_INEPTXFEMPMSK : DIEPEMPMSK_D_INEPTXFEMPMSK_Field := 16#0#;
      --  unspecified
      Reserved_16_31  : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPEMPMSK_Register use record
      D_INEPTXFEMPMSK at 0 range 0 .. 15;
      Reserved_16_31  at 0 range 16 .. 31;
   end record;

   subtype DIEPCTL0_D_MPS0_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL0_D_EPTYPE0_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL0_D_TXFNUM0_Field is ESP32S3_Registers.UInt4;

   type DIEPCTL0_Register is record
      D_MPS0         : DIEPCTL0_D_MPS0_Field := 16#0#;
      --  unspecified
      Reserved_2_14  : ESP32S3_Registers.UInt13 := 16#0#;
      --  Read-only.
      D_USBACTEP0    : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      D_NAKSTS0      : Boolean := False;
      --  Read-only.
      D_EPTYPE0      : DIEPCTL0_D_EPTYPE0_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      D_STALL0       : Boolean := False;
      D_TXFNUM0      : DIEPCTL0_D_TXFNUM0_Field := 16#0#;
      --  Write-only.
      D_CNAK0        : Boolean := False;
      --  Write-only.
      DI_SNAK0       : Boolean := False;
      --  unspecified
      Reserved_28_29 : ESP32S3_Registers.UInt2 := 16#0#;
      D_EPDIS0       : Boolean := False;
      D_EPENA0       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPCTL0_Register use record
      D_MPS0         at 0 range 0 .. 1;
      Reserved_2_14  at 0 range 2 .. 14;
      D_USBACTEP0    at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      D_NAKSTS0      at 0 range 17 .. 17;
      D_EPTYPE0      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      D_STALL0       at 0 range 21 .. 21;
      D_TXFNUM0      at 0 range 22 .. 25;
      D_CNAK0        at 0 range 26 .. 26;
      DI_SNAK0       at 0 range 27 .. 27;
      Reserved_28_29 at 0 range 28 .. 29;
      D_EPDIS0       at 0 range 30 .. 30;
      D_EPENA0       at 0 range 31 .. 31;
   end record;

   type DIEPINT0_Register is record
      D_XFERCOMPL0   : Boolean := False;
      D_EPDISBLD0    : Boolean := False;
      D_AHBERR0      : Boolean := False;
      D_TIMEOUT0     : Boolean := False;
      D_INTKNTXFEMP0 : Boolean := False;
      D_INTKNEPMIS0  : Boolean := False;
      D_INEPNAKEFF0  : Boolean := False;
      --  Read-only.
      D_TXFEMP0      : Boolean := False;
      D_TXFIFOUNDRN0 : Boolean := False;
      D_BNAINTR0     : Boolean := False;
      --  unspecified
      Reserved_10_10 : ESP32S3_Registers.Bit := 16#0#;
      D_PKTDRPSTS0   : Boolean := False;
      D_BBLEERR0     : Boolean := False;
      D_NAKINTRPT0   : Boolean := False;
      D_NYETINTRPT0  : Boolean := False;
      --  unspecified
      Reserved_15_31 : ESP32S3_Registers.UInt17 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPINT0_Register use record
      D_XFERCOMPL0   at 0 range 0 .. 0;
      D_EPDISBLD0    at 0 range 1 .. 1;
      D_AHBERR0      at 0 range 2 .. 2;
      D_TIMEOUT0     at 0 range 3 .. 3;
      D_INTKNTXFEMP0 at 0 range 4 .. 4;
      D_INTKNEPMIS0  at 0 range 5 .. 5;
      D_INEPNAKEFF0  at 0 range 6 .. 6;
      D_TXFEMP0      at 0 range 7 .. 7;
      D_TXFIFOUNDRN0 at 0 range 8 .. 8;
      D_BNAINTR0     at 0 range 9 .. 9;
      Reserved_10_10 at 0 range 10 .. 10;
      D_PKTDRPSTS0   at 0 range 11 .. 11;
      D_BBLEERR0     at 0 range 12 .. 12;
      D_NAKINTRPT0   at 0 range 13 .. 13;
      D_NYETINTRPT0  at 0 range 14 .. 14;
      Reserved_15_31 at 0 range 15 .. 31;
   end record;

   subtype DIEPTSIZ0_D_XFERSIZE0_Field is ESP32S3_Registers.UInt7;
   subtype DIEPTSIZ0_D_PKTCNT0_Field is ESP32S3_Registers.UInt2;

   type DIEPTSIZ0_Register is record
      D_XFERSIZE0    : DIEPTSIZ0_D_XFERSIZE0_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      D_PKTCNT0      : DIEPTSIZ0_D_PKTCNT0_Field := 16#0#;
      --  unspecified
      Reserved_21_31 : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPTSIZ0_Register use record
      D_XFERSIZE0    at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      D_PKTCNT0      at 0 range 19 .. 20;
      Reserved_21_31 at 0 range 21 .. 31;
   end record;

   subtype DTXFSTS0_D_INEPTXFSPCAVAIL0_Field is ESP32S3_Registers.UInt16;

   type DTXFSTS0_Register is record
      --  Read-only.
      D_INEPTXFSPCAVAIL0 : DTXFSTS0_D_INEPTXFSPCAVAIL0_Field;
      --  unspecified
      Reserved_16_31     : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DTXFSTS0_Register use record
      D_INEPTXFSPCAVAIL0 at 0 range 0 .. 15;
      Reserved_16_31     at 0 range 16 .. 31;
   end record;

   subtype DIEPCTL1_D_MPS1_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL1_D_EPTYPE1_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL1_D_TXFNUM1_Field is ESP32S3_Registers.UInt4;

   type DIEPCTL1_Register is record
      D_MPS1         : DIEPCTL1_D_MPS1_Field := 16#0#;
      --  unspecified
      Reserved_2_14  : ESP32S3_Registers.UInt13 := 16#0#;
      --  Read-only.
      D_USBACTEP1    : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      D_NAKSTS1      : Boolean := False;
      --  Read-only.
      D_EPTYPE1      : DIEPCTL1_D_EPTYPE1_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      D_STALL1       : Boolean := False;
      D_TXFNUM1      : DIEPCTL1_D_TXFNUM1_Field := 16#0#;
      --  Write-only.
      D_CNAK1        : Boolean := False;
      --  Write-only.
      DI_SNAK1       : Boolean := False;
      --  Write-only.
      DI_SETD0PID1   : Boolean := False;
      --  Write-only.
      DI_SETD1PID1   : Boolean := False;
      D_EPDIS1       : Boolean := False;
      D_EPENA1       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPCTL1_Register use record
      D_MPS1         at 0 range 0 .. 1;
      Reserved_2_14  at 0 range 2 .. 14;
      D_USBACTEP1    at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      D_NAKSTS1      at 0 range 17 .. 17;
      D_EPTYPE1      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      D_STALL1       at 0 range 21 .. 21;
      D_TXFNUM1      at 0 range 22 .. 25;
      D_CNAK1        at 0 range 26 .. 26;
      DI_SNAK1       at 0 range 27 .. 27;
      DI_SETD0PID1   at 0 range 28 .. 28;
      DI_SETD1PID1   at 0 range 29 .. 29;
      D_EPDIS1       at 0 range 30 .. 30;
      D_EPENA1       at 0 range 31 .. 31;
   end record;

   type DIEPINT1_Register is record
      D_XFERCOMPL1   : Boolean := False;
      D_EPDISBLD1    : Boolean := False;
      D_AHBERR1      : Boolean := False;
      D_TIMEOUT1     : Boolean := False;
      D_INTKNTXFEMP1 : Boolean := False;
      D_INTKNEPMIS1  : Boolean := False;
      D_INEPNAKEFF1  : Boolean := False;
      --  Read-only.
      D_TXFEMP1      : Boolean := False;
      D_TXFIFOUNDRN1 : Boolean := False;
      D_BNAINTR1     : Boolean := False;
      --  unspecified
      Reserved_10_10 : ESP32S3_Registers.Bit := 16#0#;
      D_PKTDRPSTS1   : Boolean := False;
      D_BBLEERR1     : Boolean := False;
      D_NAKINTRPT1   : Boolean := False;
      D_NYETINTRPT1  : Boolean := False;
      --  unspecified
      Reserved_15_31 : ESP32S3_Registers.UInt17 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPINT1_Register use record
      D_XFERCOMPL1   at 0 range 0 .. 0;
      D_EPDISBLD1    at 0 range 1 .. 1;
      D_AHBERR1      at 0 range 2 .. 2;
      D_TIMEOUT1     at 0 range 3 .. 3;
      D_INTKNTXFEMP1 at 0 range 4 .. 4;
      D_INTKNEPMIS1  at 0 range 5 .. 5;
      D_INEPNAKEFF1  at 0 range 6 .. 6;
      D_TXFEMP1      at 0 range 7 .. 7;
      D_TXFIFOUNDRN1 at 0 range 8 .. 8;
      D_BNAINTR1     at 0 range 9 .. 9;
      Reserved_10_10 at 0 range 10 .. 10;
      D_PKTDRPSTS1   at 0 range 11 .. 11;
      D_BBLEERR1     at 0 range 12 .. 12;
      D_NAKINTRPT1   at 0 range 13 .. 13;
      D_NYETINTRPT1  at 0 range 14 .. 14;
      Reserved_15_31 at 0 range 15 .. 31;
   end record;

   subtype DIEPTSIZ1_D_XFERSIZE1_Field is ESP32S3_Registers.UInt7;
   subtype DIEPTSIZ1_D_PKTCNT1_Field is ESP32S3_Registers.UInt2;

   type DIEPTSIZ1_Register is record
      D_XFERSIZE1    : DIEPTSIZ1_D_XFERSIZE1_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      D_PKTCNT1      : DIEPTSIZ1_D_PKTCNT1_Field := 16#0#;
      --  unspecified
      Reserved_21_31 : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPTSIZ1_Register use record
      D_XFERSIZE1    at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      D_PKTCNT1      at 0 range 19 .. 20;
      Reserved_21_31 at 0 range 21 .. 31;
   end record;

   subtype DTXFSTS1_D_INEPTXFSPCAVAIL1_Field is ESP32S3_Registers.UInt16;

   type DTXFSTS1_Register is record
      --  Read-only.
      D_INEPTXFSPCAVAIL1 : DTXFSTS1_D_INEPTXFSPCAVAIL1_Field;
      --  unspecified
      Reserved_16_31     : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DTXFSTS1_Register use record
      D_INEPTXFSPCAVAIL1 at 0 range 0 .. 15;
      Reserved_16_31     at 0 range 16 .. 31;
   end record;

   subtype DIEPCTL2_D_MPS2_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL2_D_EPTYPE2_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL2_D_TXFNUM2_Field is ESP32S3_Registers.UInt4;

   type DIEPCTL2_Register is record
      D_MPS2         : DIEPCTL2_D_MPS2_Field := 16#0#;
      --  unspecified
      Reserved_2_14  : ESP32S3_Registers.UInt13 := 16#0#;
      --  Read-only.
      D_USBACTEP2    : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      D_NAKSTS2      : Boolean := False;
      --  Read-only.
      D_EPTYPE2      : DIEPCTL2_D_EPTYPE2_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      D_STALL2       : Boolean := False;
      D_TXFNUM2      : DIEPCTL2_D_TXFNUM2_Field := 16#0#;
      --  Write-only.
      D_CNAK2        : Boolean := False;
      --  Write-only.
      DI_SNAK2       : Boolean := False;
      --  Write-only.
      DI_SETD0PID2   : Boolean := False;
      --  Write-only.
      DI_SETD1PID2   : Boolean := False;
      D_EPDIS2       : Boolean := False;
      D_EPENA2       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPCTL2_Register use record
      D_MPS2         at 0 range 0 .. 1;
      Reserved_2_14  at 0 range 2 .. 14;
      D_USBACTEP2    at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      D_NAKSTS2      at 0 range 17 .. 17;
      D_EPTYPE2      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      D_STALL2       at 0 range 21 .. 21;
      D_TXFNUM2      at 0 range 22 .. 25;
      D_CNAK2        at 0 range 26 .. 26;
      DI_SNAK2       at 0 range 27 .. 27;
      DI_SETD0PID2   at 0 range 28 .. 28;
      DI_SETD1PID2   at 0 range 29 .. 29;
      D_EPDIS2       at 0 range 30 .. 30;
      D_EPENA2       at 0 range 31 .. 31;
   end record;

   type DIEPINT2_Register is record
      D_XFERCOMPL2   : Boolean := False;
      D_EPDISBLD2    : Boolean := False;
      D_AHBERR2      : Boolean := False;
      D_TIMEOUT2     : Boolean := False;
      D_INTKNTXFEMP2 : Boolean := False;
      D_INTKNEPMIS2  : Boolean := False;
      D_INEPNAKEFF2  : Boolean := False;
      --  Read-only.
      D_TXFEMP2      : Boolean := False;
      D_TXFIFOUNDRN2 : Boolean := False;
      D_BNAINTR2     : Boolean := False;
      --  unspecified
      Reserved_10_10 : ESP32S3_Registers.Bit := 16#0#;
      D_PKTDRPSTS2   : Boolean := False;
      D_BBLEERR2     : Boolean := False;
      D_NAKINTRPT2   : Boolean := False;
      D_NYETINTRPT2  : Boolean := False;
      --  unspecified
      Reserved_15_31 : ESP32S3_Registers.UInt17 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPINT2_Register use record
      D_XFERCOMPL2   at 0 range 0 .. 0;
      D_EPDISBLD2    at 0 range 1 .. 1;
      D_AHBERR2      at 0 range 2 .. 2;
      D_TIMEOUT2     at 0 range 3 .. 3;
      D_INTKNTXFEMP2 at 0 range 4 .. 4;
      D_INTKNEPMIS2  at 0 range 5 .. 5;
      D_INEPNAKEFF2  at 0 range 6 .. 6;
      D_TXFEMP2      at 0 range 7 .. 7;
      D_TXFIFOUNDRN2 at 0 range 8 .. 8;
      D_BNAINTR2     at 0 range 9 .. 9;
      Reserved_10_10 at 0 range 10 .. 10;
      D_PKTDRPSTS2   at 0 range 11 .. 11;
      D_BBLEERR2     at 0 range 12 .. 12;
      D_NAKINTRPT2   at 0 range 13 .. 13;
      D_NYETINTRPT2  at 0 range 14 .. 14;
      Reserved_15_31 at 0 range 15 .. 31;
   end record;

   subtype DIEPTSIZ2_D_XFERSIZE2_Field is ESP32S3_Registers.UInt7;
   subtype DIEPTSIZ2_D_PKTCNT2_Field is ESP32S3_Registers.UInt2;

   type DIEPTSIZ2_Register is record
      D_XFERSIZE2    : DIEPTSIZ2_D_XFERSIZE2_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      D_PKTCNT2      : DIEPTSIZ2_D_PKTCNT2_Field := 16#0#;
      --  unspecified
      Reserved_21_31 : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPTSIZ2_Register use record
      D_XFERSIZE2    at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      D_PKTCNT2      at 0 range 19 .. 20;
      Reserved_21_31 at 0 range 21 .. 31;
   end record;

   subtype DTXFSTS2_D_INEPTXFSPCAVAIL2_Field is ESP32S3_Registers.UInt16;

   type DTXFSTS2_Register is record
      --  Read-only.
      D_INEPTXFSPCAVAIL2 : DTXFSTS2_D_INEPTXFSPCAVAIL2_Field;
      --  unspecified
      Reserved_16_31     : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DTXFSTS2_Register use record
      D_INEPTXFSPCAVAIL2 at 0 range 0 .. 15;
      Reserved_16_31     at 0 range 16 .. 31;
   end record;

   subtype DIEPCTL3_DI_MPS3_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL3_DI_EPTYPE3_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL3_DI_TXFNUM3_Field is ESP32S3_Registers.UInt4;

   type DIEPCTL3_Register is record
      DI_MPS3        : DIEPCTL3_DI_MPS3_Field := 16#0#;
      --  unspecified
      Reserved_2_14  : ESP32S3_Registers.UInt13 := 16#0#;
      --  Read-only.
      DI_USBACTEP3   : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      DI_NAKSTS3     : Boolean := False;
      --  Read-only.
      DI_EPTYPE3     : DIEPCTL3_DI_EPTYPE3_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      DI_STALL3      : Boolean := False;
      DI_TXFNUM3     : DIEPCTL3_DI_TXFNUM3_Field := 16#0#;
      --  Write-only.
      DI_CNAK3       : Boolean := False;
      --  Write-only.
      DI_SNAK3       : Boolean := False;
      --  Write-only.
      DI_SETD0PID3   : Boolean := False;
      --  Write-only.
      DI_SETD1PID3   : Boolean := False;
      DI_EPDIS3      : Boolean := False;
      DI_EPENA3      : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPCTL3_Register use record
      DI_MPS3        at 0 range 0 .. 1;
      Reserved_2_14  at 0 range 2 .. 14;
      DI_USBACTEP3   at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      DI_NAKSTS3     at 0 range 17 .. 17;
      DI_EPTYPE3     at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      DI_STALL3      at 0 range 21 .. 21;
      DI_TXFNUM3     at 0 range 22 .. 25;
      DI_CNAK3       at 0 range 26 .. 26;
      DI_SNAK3       at 0 range 27 .. 27;
      DI_SETD0PID3   at 0 range 28 .. 28;
      DI_SETD1PID3   at 0 range 29 .. 29;
      DI_EPDIS3      at 0 range 30 .. 30;
      DI_EPENA3      at 0 range 31 .. 31;
   end record;

   type DIEPINT3_Register is record
      D_XFERCOMPL3   : Boolean := False;
      D_EPDISBLD3    : Boolean := False;
      D_AHBERR3      : Boolean := False;
      D_TIMEOUT3     : Boolean := False;
      D_INTKNTXFEMP3 : Boolean := False;
      D_INTKNEPMIS3  : Boolean := False;
      D_INEPNAKEFF3  : Boolean := False;
      --  Read-only.
      D_TXFEMP3      : Boolean := False;
      D_TXFIFOUNDRN3 : Boolean := False;
      D_BNAINTR3     : Boolean := False;
      --  unspecified
      Reserved_10_10 : ESP32S3_Registers.Bit := 16#0#;
      D_PKTDRPSTS3   : Boolean := False;
      D_BBLEERR3     : Boolean := False;
      D_NAKINTRPT3   : Boolean := False;
      D_NYETINTRPT3  : Boolean := False;
      --  unspecified
      Reserved_15_31 : ESP32S3_Registers.UInt17 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPINT3_Register use record
      D_XFERCOMPL3   at 0 range 0 .. 0;
      D_EPDISBLD3    at 0 range 1 .. 1;
      D_AHBERR3      at 0 range 2 .. 2;
      D_TIMEOUT3     at 0 range 3 .. 3;
      D_INTKNTXFEMP3 at 0 range 4 .. 4;
      D_INTKNEPMIS3  at 0 range 5 .. 5;
      D_INEPNAKEFF3  at 0 range 6 .. 6;
      D_TXFEMP3      at 0 range 7 .. 7;
      D_TXFIFOUNDRN3 at 0 range 8 .. 8;
      D_BNAINTR3     at 0 range 9 .. 9;
      Reserved_10_10 at 0 range 10 .. 10;
      D_PKTDRPSTS3   at 0 range 11 .. 11;
      D_BBLEERR3     at 0 range 12 .. 12;
      D_NAKINTRPT3   at 0 range 13 .. 13;
      D_NYETINTRPT3  at 0 range 14 .. 14;
      Reserved_15_31 at 0 range 15 .. 31;
   end record;

   subtype DIEPTSIZ3_D_XFERSIZE3_Field is ESP32S3_Registers.UInt7;
   subtype DIEPTSIZ3_D_PKTCNT3_Field is ESP32S3_Registers.UInt2;

   type DIEPTSIZ3_Register is record
      D_XFERSIZE3    : DIEPTSIZ3_D_XFERSIZE3_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      D_PKTCNT3      : DIEPTSIZ3_D_PKTCNT3_Field := 16#0#;
      --  unspecified
      Reserved_21_31 : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPTSIZ3_Register use record
      D_XFERSIZE3    at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      D_PKTCNT3      at 0 range 19 .. 20;
      Reserved_21_31 at 0 range 21 .. 31;
   end record;

   subtype DTXFSTS3_D_INEPTXFSPCAVAIL3_Field is ESP32S3_Registers.UInt16;

   type DTXFSTS3_Register is record
      --  Read-only.
      D_INEPTXFSPCAVAIL3 : DTXFSTS3_D_INEPTXFSPCAVAIL3_Field;
      --  unspecified
      Reserved_16_31     : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DTXFSTS3_Register use record
      D_INEPTXFSPCAVAIL3 at 0 range 0 .. 15;
      Reserved_16_31     at 0 range 16 .. 31;
   end record;

   subtype DIEPCTL4_D_MPS4_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL4_D_EPTYPE4_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL4_D_TXFNUM4_Field is ESP32S3_Registers.UInt4;

   type DIEPCTL4_Register is record
      D_MPS4         : DIEPCTL4_D_MPS4_Field := 16#0#;
      --  unspecified
      Reserved_2_14  : ESP32S3_Registers.UInt13 := 16#0#;
      --  Read-only.
      D_USBACTEP4    : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      D_NAKSTS4      : Boolean := False;
      --  Read-only.
      D_EPTYPE4      : DIEPCTL4_D_EPTYPE4_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      D_STALL4       : Boolean := False;
      D_TXFNUM4      : DIEPCTL4_D_TXFNUM4_Field := 16#0#;
      --  Write-only.
      D_CNAK4        : Boolean := False;
      --  Write-only.
      DI_SNAK4       : Boolean := False;
      --  Write-only.
      DI_SETD0PID4   : Boolean := False;
      --  Write-only.
      DI_SETD1PID4   : Boolean := False;
      D_EPDIS4       : Boolean := False;
      D_EPENA4       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPCTL4_Register use record
      D_MPS4         at 0 range 0 .. 1;
      Reserved_2_14  at 0 range 2 .. 14;
      D_USBACTEP4    at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      D_NAKSTS4      at 0 range 17 .. 17;
      D_EPTYPE4      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      D_STALL4       at 0 range 21 .. 21;
      D_TXFNUM4      at 0 range 22 .. 25;
      D_CNAK4        at 0 range 26 .. 26;
      DI_SNAK4       at 0 range 27 .. 27;
      DI_SETD0PID4   at 0 range 28 .. 28;
      DI_SETD1PID4   at 0 range 29 .. 29;
      D_EPDIS4       at 0 range 30 .. 30;
      D_EPENA4       at 0 range 31 .. 31;
   end record;

   type DIEPINT4_Register is record
      D_XFERCOMPL4   : Boolean := False;
      D_EPDISBLD4    : Boolean := False;
      D_AHBERR4      : Boolean := False;
      D_TIMEOUT4     : Boolean := False;
      D_INTKNTXFEMP4 : Boolean := False;
      D_INTKNEPMIS4  : Boolean := False;
      D_INEPNAKEFF4  : Boolean := False;
      --  Read-only.
      D_TXFEMP4      : Boolean := False;
      D_TXFIFOUNDRN4 : Boolean := False;
      D_BNAINTR4     : Boolean := False;
      --  unspecified
      Reserved_10_10 : ESP32S3_Registers.Bit := 16#0#;
      D_PKTDRPSTS4   : Boolean := False;
      D_BBLEERR4     : Boolean := False;
      D_NAKINTRPT4   : Boolean := False;
      D_NYETINTRPT4  : Boolean := False;
      --  unspecified
      Reserved_15_31 : ESP32S3_Registers.UInt17 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPINT4_Register use record
      D_XFERCOMPL4   at 0 range 0 .. 0;
      D_EPDISBLD4    at 0 range 1 .. 1;
      D_AHBERR4      at 0 range 2 .. 2;
      D_TIMEOUT4     at 0 range 3 .. 3;
      D_INTKNTXFEMP4 at 0 range 4 .. 4;
      D_INTKNEPMIS4  at 0 range 5 .. 5;
      D_INEPNAKEFF4  at 0 range 6 .. 6;
      D_TXFEMP4      at 0 range 7 .. 7;
      D_TXFIFOUNDRN4 at 0 range 8 .. 8;
      D_BNAINTR4     at 0 range 9 .. 9;
      Reserved_10_10 at 0 range 10 .. 10;
      D_PKTDRPSTS4   at 0 range 11 .. 11;
      D_BBLEERR4     at 0 range 12 .. 12;
      D_NAKINTRPT4   at 0 range 13 .. 13;
      D_NYETINTRPT4  at 0 range 14 .. 14;
      Reserved_15_31 at 0 range 15 .. 31;
   end record;

   subtype DIEPTSIZ4_D_XFERSIZE4_Field is ESP32S3_Registers.UInt7;
   subtype DIEPTSIZ4_D_PKTCNT4_Field is ESP32S3_Registers.UInt2;

   type DIEPTSIZ4_Register is record
      D_XFERSIZE4    : DIEPTSIZ4_D_XFERSIZE4_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      D_PKTCNT4      : DIEPTSIZ4_D_PKTCNT4_Field := 16#0#;
      --  unspecified
      Reserved_21_31 : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPTSIZ4_Register use record
      D_XFERSIZE4    at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      D_PKTCNT4      at 0 range 19 .. 20;
      Reserved_21_31 at 0 range 21 .. 31;
   end record;

   subtype DTXFSTS4_D_INEPTXFSPCAVAIL4_Field is ESP32S3_Registers.UInt16;

   type DTXFSTS4_Register is record
      --  Read-only.
      D_INEPTXFSPCAVAIL4 : DTXFSTS4_D_INEPTXFSPCAVAIL4_Field;
      --  unspecified
      Reserved_16_31     : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DTXFSTS4_Register use record
      D_INEPTXFSPCAVAIL4 at 0 range 0 .. 15;
      Reserved_16_31     at 0 range 16 .. 31;
   end record;

   subtype DIEPCTL5_DI_MPS5_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL5_DI_EPTYPE5_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL5_DI_TXFNUM5_Field is ESP32S3_Registers.UInt4;

   type DIEPCTL5_Register is record
      DI_MPS5        : DIEPCTL5_DI_MPS5_Field := 16#0#;
      --  unspecified
      Reserved_2_14  : ESP32S3_Registers.UInt13 := 16#0#;
      --  Read-only.
      DI_USBACTEP5   : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      DI_NAKSTS5     : Boolean := False;
      --  Read-only.
      DI_EPTYPE5     : DIEPCTL5_DI_EPTYPE5_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      DI_STALL5      : Boolean := False;
      DI_TXFNUM5     : DIEPCTL5_DI_TXFNUM5_Field := 16#0#;
      --  Write-only.
      DI_CNAK5       : Boolean := False;
      --  Write-only.
      DI_SNAK5       : Boolean := False;
      --  Write-only.
      DI_SETD0PID5   : Boolean := False;
      --  Write-only.
      DI_SETD1PID5   : Boolean := False;
      DI_EPDIS5      : Boolean := False;
      DI_EPENA5      : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPCTL5_Register use record
      DI_MPS5        at 0 range 0 .. 1;
      Reserved_2_14  at 0 range 2 .. 14;
      DI_USBACTEP5   at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      DI_NAKSTS5     at 0 range 17 .. 17;
      DI_EPTYPE5     at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      DI_STALL5      at 0 range 21 .. 21;
      DI_TXFNUM5     at 0 range 22 .. 25;
      DI_CNAK5       at 0 range 26 .. 26;
      DI_SNAK5       at 0 range 27 .. 27;
      DI_SETD0PID5   at 0 range 28 .. 28;
      DI_SETD1PID5   at 0 range 29 .. 29;
      DI_EPDIS5      at 0 range 30 .. 30;
      DI_EPENA5      at 0 range 31 .. 31;
   end record;

   type DIEPINT5_Register is record
      D_XFERCOMPL5   : Boolean := False;
      D_EPDISBLD5    : Boolean := False;
      D_AHBERR5      : Boolean := False;
      D_TIMEOUT5     : Boolean := False;
      D_INTKNTXFEMP5 : Boolean := False;
      D_INTKNEPMIS5  : Boolean := False;
      D_INEPNAKEFF5  : Boolean := False;
      --  Read-only.
      D_TXFEMP5      : Boolean := False;
      D_TXFIFOUNDRN5 : Boolean := False;
      D_BNAINTR5     : Boolean := False;
      --  unspecified
      Reserved_10_10 : ESP32S3_Registers.Bit := 16#0#;
      D_PKTDRPSTS5   : Boolean := False;
      D_BBLEERR5     : Boolean := False;
      D_NAKINTRPT5   : Boolean := False;
      D_NYETINTRPT5  : Boolean := False;
      --  unspecified
      Reserved_15_31 : ESP32S3_Registers.UInt17 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPINT5_Register use record
      D_XFERCOMPL5   at 0 range 0 .. 0;
      D_EPDISBLD5    at 0 range 1 .. 1;
      D_AHBERR5      at 0 range 2 .. 2;
      D_TIMEOUT5     at 0 range 3 .. 3;
      D_INTKNTXFEMP5 at 0 range 4 .. 4;
      D_INTKNEPMIS5  at 0 range 5 .. 5;
      D_INEPNAKEFF5  at 0 range 6 .. 6;
      D_TXFEMP5      at 0 range 7 .. 7;
      D_TXFIFOUNDRN5 at 0 range 8 .. 8;
      D_BNAINTR5     at 0 range 9 .. 9;
      Reserved_10_10 at 0 range 10 .. 10;
      D_PKTDRPSTS5   at 0 range 11 .. 11;
      D_BBLEERR5     at 0 range 12 .. 12;
      D_NAKINTRPT5   at 0 range 13 .. 13;
      D_NYETINTRPT5  at 0 range 14 .. 14;
      Reserved_15_31 at 0 range 15 .. 31;
   end record;

   subtype DIEPTSIZ5_D_XFERSIZE5_Field is ESP32S3_Registers.UInt7;
   subtype DIEPTSIZ5_D_PKTCNT5_Field is ESP32S3_Registers.UInt2;

   type DIEPTSIZ5_Register is record
      D_XFERSIZE5    : DIEPTSIZ5_D_XFERSIZE5_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      D_PKTCNT5      : DIEPTSIZ5_D_PKTCNT5_Field := 16#0#;
      --  unspecified
      Reserved_21_31 : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPTSIZ5_Register use record
      D_XFERSIZE5    at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      D_PKTCNT5      at 0 range 19 .. 20;
      Reserved_21_31 at 0 range 21 .. 31;
   end record;

   subtype DTXFSTS5_D_INEPTXFSPCAVAIL5_Field is ESP32S3_Registers.UInt16;

   type DTXFSTS5_Register is record
      --  Read-only.
      D_INEPTXFSPCAVAIL5 : DTXFSTS5_D_INEPTXFSPCAVAIL5_Field;
      --  unspecified
      Reserved_16_31     : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DTXFSTS5_Register use record
      D_INEPTXFSPCAVAIL5 at 0 range 0 .. 15;
      Reserved_16_31     at 0 range 16 .. 31;
   end record;

   subtype DIEPCTL6_D_MPS6_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL6_D_EPTYPE6_Field is ESP32S3_Registers.UInt2;
   subtype DIEPCTL6_D_TXFNUM6_Field is ESP32S3_Registers.UInt4;

   type DIEPCTL6_Register is record
      D_MPS6         : DIEPCTL6_D_MPS6_Field := 16#0#;
      --  unspecified
      Reserved_2_14  : ESP32S3_Registers.UInt13 := 16#0#;
      --  Read-only.
      D_USBACTEP6    : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      D_NAKSTS6      : Boolean := False;
      --  Read-only.
      D_EPTYPE6      : DIEPCTL6_D_EPTYPE6_Field := 16#0#;
      --  unspecified
      Reserved_20_20 : ESP32S3_Registers.Bit := 16#0#;
      D_STALL6       : Boolean := False;
      D_TXFNUM6      : DIEPCTL6_D_TXFNUM6_Field := 16#0#;
      --  Write-only.
      D_CNAK6        : Boolean := False;
      --  Write-only.
      DI_SNAK6       : Boolean := False;
      --  Write-only.
      DI_SETD0PID6   : Boolean := False;
      --  Write-only.
      DI_SETD1PID6   : Boolean := False;
      D_EPDIS6       : Boolean := False;
      D_EPENA6       : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPCTL6_Register use record
      D_MPS6         at 0 range 0 .. 1;
      Reserved_2_14  at 0 range 2 .. 14;
      D_USBACTEP6    at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      D_NAKSTS6      at 0 range 17 .. 17;
      D_EPTYPE6      at 0 range 18 .. 19;
      Reserved_20_20 at 0 range 20 .. 20;
      D_STALL6       at 0 range 21 .. 21;
      D_TXFNUM6      at 0 range 22 .. 25;
      D_CNAK6        at 0 range 26 .. 26;
      DI_SNAK6       at 0 range 27 .. 27;
      DI_SETD0PID6   at 0 range 28 .. 28;
      DI_SETD1PID6   at 0 range 29 .. 29;
      D_EPDIS6       at 0 range 30 .. 30;
      D_EPENA6       at 0 range 31 .. 31;
   end record;

   type DIEPINT6_Register is record
      D_XFERCOMPL6   : Boolean := False;
      D_EPDISBLD6    : Boolean := False;
      D_AHBERR6      : Boolean := False;
      D_TIMEOUT6     : Boolean := False;
      D_INTKNTXFEMP6 : Boolean := False;
      D_INTKNEPMIS6  : Boolean := False;
      D_INEPNAKEFF6  : Boolean := False;
      --  Read-only.
      D_TXFEMP6      : Boolean := False;
      D_TXFIFOUNDRN6 : Boolean := False;
      D_BNAINTR6     : Boolean := False;
      --  unspecified
      Reserved_10_10 : ESP32S3_Registers.Bit := 16#0#;
      D_PKTDRPSTS6   : Boolean := False;
      D_BBLEERR6     : Boolean := False;
      D_NAKINTRPT6   : Boolean := False;
      D_NYETINTRPT6  : Boolean := False;
      --  unspecified
      Reserved_15_31 : ESP32S3_Registers.UInt17 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPINT6_Register use record
      D_XFERCOMPL6   at 0 range 0 .. 0;
      D_EPDISBLD6    at 0 range 1 .. 1;
      D_AHBERR6      at 0 range 2 .. 2;
      D_TIMEOUT6     at 0 range 3 .. 3;
      D_INTKNTXFEMP6 at 0 range 4 .. 4;
      D_INTKNEPMIS6  at 0 range 5 .. 5;
      D_INEPNAKEFF6  at 0 range 6 .. 6;
      D_TXFEMP6      at 0 range 7 .. 7;
      D_TXFIFOUNDRN6 at 0 range 8 .. 8;
      D_BNAINTR6     at 0 range 9 .. 9;
      Reserved_10_10 at 0 range 10 .. 10;
      D_PKTDRPSTS6   at 0 range 11 .. 11;
      D_BBLEERR6     at 0 range 12 .. 12;
      D_NAKINTRPT6   at 0 range 13 .. 13;
      D_NYETINTRPT6  at 0 range 14 .. 14;
      Reserved_15_31 at 0 range 15 .. 31;
   end record;

   subtype DIEPTSIZ6_D_XFERSIZE6_Field is ESP32S3_Registers.UInt7;
   subtype DIEPTSIZ6_D_PKTCNT6_Field is ESP32S3_Registers.UInt2;

   type DIEPTSIZ6_Register is record
      D_XFERSIZE6    : DIEPTSIZ6_D_XFERSIZE6_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      D_PKTCNT6      : DIEPTSIZ6_D_PKTCNT6_Field := 16#0#;
      --  unspecified
      Reserved_21_31 : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIEPTSIZ6_Register use record
      D_XFERSIZE6    at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      D_PKTCNT6      at 0 range 19 .. 20;
      Reserved_21_31 at 0 range 21 .. 31;
   end record;

   subtype DTXFSTS6_D_INEPTXFSPCAVAIL6_Field is ESP32S3_Registers.UInt16;

   type DTXFSTS6_Register is record
      --  Read-only.
      D_INEPTXFSPCAVAIL6 : DTXFSTS6_D_INEPTXFSPCAVAIL6_Field;
      --  unspecified
      Reserved_16_31     : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DTXFSTS6_Register use record
      D_INEPTXFSPCAVAIL6 at 0 range 0 .. 15;
      Reserved_16_31     at 0 range 16 .. 31;
   end record;

   subtype DOEPCTL0_MPS0_Field is ESP32S3_Registers.UInt2;
   subtype DOEPCTL0_EPTYPE0_Field is ESP32S3_Registers.UInt2;

   type DOEPCTL0_Register is record
      --  Read-only.
      MPS0           : DOEPCTL0_MPS0_Field := 16#0#;
      --  unspecified
      Reserved_2_14  : ESP32S3_Registers.UInt13 := 16#0#;
      --  Read-only.
      USBACTEP0      : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      NAKSTS0        : Boolean := False;
      --  Read-only.
      EPTYPE0        : DOEPCTL0_EPTYPE0_Field := 16#0#;
      SNP0           : Boolean := False;
      STALL0         : Boolean := False;
      --  unspecified
      Reserved_22_25 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Write-only.
      CNAK0          : Boolean := False;
      --  Write-only.
      DO_SNAK0       : Boolean := False;
      --  unspecified
      Reserved_28_29 : ESP32S3_Registers.UInt2 := 16#0#;
      --  Read-only.
      EPDIS0         : Boolean := False;
      EPENA0         : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPCTL0_Register use record
      MPS0           at 0 range 0 .. 1;
      Reserved_2_14  at 0 range 2 .. 14;
      USBACTEP0      at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      NAKSTS0        at 0 range 17 .. 17;
      EPTYPE0        at 0 range 18 .. 19;
      SNP0           at 0 range 20 .. 20;
      STALL0         at 0 range 21 .. 21;
      Reserved_22_25 at 0 range 22 .. 25;
      CNAK0          at 0 range 26 .. 26;
      DO_SNAK0       at 0 range 27 .. 27;
      Reserved_28_29 at 0 range 28 .. 29;
      EPDIS0         at 0 range 30 .. 30;
      EPENA0         at 0 range 31 .. 31;
   end record;

   type DOEPINT0_Register is record
      XFERCOMPL0      : Boolean := False;
      EPDISBLD0       : Boolean := False;
      AHBERR0         : Boolean := False;
      SETUP0          : Boolean := False;
      OUTTKNEPDIS0    : Boolean := False;
      STSPHSERCVD0    : Boolean := False;
      BACK2BACKSETUP0 : Boolean := False;
      --  unspecified
      Reserved_7_7    : ESP32S3_Registers.Bit := 16#0#;
      OUTPKTERR0      : Boolean := False;
      BNAINTR0        : Boolean := False;
      --  unspecified
      Reserved_10_10  : ESP32S3_Registers.Bit := 16#0#;
      PKTDRPSTS0      : Boolean := False;
      BBLEERR0        : Boolean := False;
      NAKINTRPT0      : Boolean := False;
      NYEPINTRPT0     : Boolean := False;
      STUPPKTRCVD0    : Boolean := False;
      --  unspecified
      Reserved_16_31  : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPINT0_Register use record
      XFERCOMPL0      at 0 range 0 .. 0;
      EPDISBLD0       at 0 range 1 .. 1;
      AHBERR0         at 0 range 2 .. 2;
      SETUP0          at 0 range 3 .. 3;
      OUTTKNEPDIS0    at 0 range 4 .. 4;
      STSPHSERCVD0    at 0 range 5 .. 5;
      BACK2BACKSETUP0 at 0 range 6 .. 6;
      Reserved_7_7    at 0 range 7 .. 7;
      OUTPKTERR0      at 0 range 8 .. 8;
      BNAINTR0        at 0 range 9 .. 9;
      Reserved_10_10  at 0 range 10 .. 10;
      PKTDRPSTS0      at 0 range 11 .. 11;
      BBLEERR0        at 0 range 12 .. 12;
      NAKINTRPT0      at 0 range 13 .. 13;
      NYEPINTRPT0     at 0 range 14 .. 14;
      STUPPKTRCVD0    at 0 range 15 .. 15;
      Reserved_16_31  at 0 range 16 .. 31;
   end record;

   subtype DOEPTSIZ0_XFERSIZE0_Field is ESP32S3_Registers.UInt7;
   subtype DOEPTSIZ0_SUPCNT0_Field is ESP32S3_Registers.UInt2;

   type DOEPTSIZ0_Register is record
      XFERSIZE0      : DOEPTSIZ0_XFERSIZE0_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      PKTCNT0        : Boolean := False;
      --  unspecified
      Reserved_20_28 : ESP32S3_Registers.UInt9 := 16#0#;
      SUPCNT0        : DOEPTSIZ0_SUPCNT0_Field := 16#0#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPTSIZ0_Register use record
      XFERSIZE0      at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      PKTCNT0        at 0 range 19 .. 19;
      Reserved_20_28 at 0 range 20 .. 28;
      SUPCNT0        at 0 range 29 .. 30;
      Reserved_31_31 at 0 range 31 .. 31;
   end record;

   subtype DOEPCTL1_MPS1_Field is ESP32S3_Registers.UInt11;
   subtype DOEPCTL1_EPTYPE1_Field is ESP32S3_Registers.UInt2;

   type DOEPCTL1_Register is record
      --  Read-only.
      MPS1           : DOEPCTL1_MPS1_Field := 16#0#;
      --  unspecified
      Reserved_11_14 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Read-only.
      USBACTEP1      : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      NAKSTS1        : Boolean := False;
      --  Read-only.
      EPTYPE1        : DOEPCTL1_EPTYPE1_Field := 16#0#;
      SNP1           : Boolean := False;
      STALL1         : Boolean := False;
      --  unspecified
      Reserved_22_25 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Write-only.
      CNAK1          : Boolean := False;
      --  Write-only.
      DO_SNAK1       : Boolean := False;
      --  Write-only.
      DO_SETD0PID1   : Boolean := False;
      --  Write-only.
      DO_SETD1PID1   : Boolean := False;
      --  Read-only.
      EPDIS1         : Boolean := False;
      EPENA1         : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPCTL1_Register use record
      MPS1           at 0 range 0 .. 10;
      Reserved_11_14 at 0 range 11 .. 14;
      USBACTEP1      at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      NAKSTS1        at 0 range 17 .. 17;
      EPTYPE1        at 0 range 18 .. 19;
      SNP1           at 0 range 20 .. 20;
      STALL1         at 0 range 21 .. 21;
      Reserved_22_25 at 0 range 22 .. 25;
      CNAK1          at 0 range 26 .. 26;
      DO_SNAK1       at 0 range 27 .. 27;
      DO_SETD0PID1   at 0 range 28 .. 28;
      DO_SETD1PID1   at 0 range 29 .. 29;
      EPDIS1         at 0 range 30 .. 30;
      EPENA1         at 0 range 31 .. 31;
   end record;

   type DOEPINT1_Register is record
      XFERCOMPL1      : Boolean := False;
      EPDISBLD1       : Boolean := False;
      AHBERR1         : Boolean := False;
      SETUP1          : Boolean := False;
      OUTTKNEPDIS1    : Boolean := False;
      STSPHSERCVD1    : Boolean := False;
      BACK2BACKSETUP1 : Boolean := False;
      --  unspecified
      Reserved_7_7    : ESP32S3_Registers.Bit := 16#0#;
      OUTPKTERR1      : Boolean := False;
      BNAINTR1        : Boolean := False;
      --  unspecified
      Reserved_10_10  : ESP32S3_Registers.Bit := 16#0#;
      PKTDRPSTS1      : Boolean := False;
      BBLEERR1        : Boolean := False;
      NAKINTRPT1      : Boolean := False;
      NYEPINTRPT1     : Boolean := False;
      STUPPKTRCVD1    : Boolean := False;
      --  unspecified
      Reserved_16_31  : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPINT1_Register use record
      XFERCOMPL1      at 0 range 0 .. 0;
      EPDISBLD1       at 0 range 1 .. 1;
      AHBERR1         at 0 range 2 .. 2;
      SETUP1          at 0 range 3 .. 3;
      OUTTKNEPDIS1    at 0 range 4 .. 4;
      STSPHSERCVD1    at 0 range 5 .. 5;
      BACK2BACKSETUP1 at 0 range 6 .. 6;
      Reserved_7_7    at 0 range 7 .. 7;
      OUTPKTERR1      at 0 range 8 .. 8;
      BNAINTR1        at 0 range 9 .. 9;
      Reserved_10_10  at 0 range 10 .. 10;
      PKTDRPSTS1      at 0 range 11 .. 11;
      BBLEERR1        at 0 range 12 .. 12;
      NAKINTRPT1      at 0 range 13 .. 13;
      NYEPINTRPT1     at 0 range 14 .. 14;
      STUPPKTRCVD1    at 0 range 15 .. 15;
      Reserved_16_31  at 0 range 16 .. 31;
   end record;

   subtype DOEPTSIZ1_XFERSIZE1_Field is ESP32S3_Registers.UInt7;
   subtype DOEPTSIZ1_SUPCNT1_Field is ESP32S3_Registers.UInt2;

   type DOEPTSIZ1_Register is record
      XFERSIZE1      : DOEPTSIZ1_XFERSIZE1_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      PKTCNT1        : Boolean := False;
      --  unspecified
      Reserved_20_28 : ESP32S3_Registers.UInt9 := 16#0#;
      SUPCNT1        : DOEPTSIZ1_SUPCNT1_Field := 16#0#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPTSIZ1_Register use record
      XFERSIZE1      at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      PKTCNT1        at 0 range 19 .. 19;
      Reserved_20_28 at 0 range 20 .. 28;
      SUPCNT1        at 0 range 29 .. 30;
      Reserved_31_31 at 0 range 31 .. 31;
   end record;

   subtype DOEPCTL2_MPS2_Field is ESP32S3_Registers.UInt11;
   subtype DOEPCTL2_EPTYPE2_Field is ESP32S3_Registers.UInt2;

   type DOEPCTL2_Register is record
      --  Read-only.
      MPS2           : DOEPCTL2_MPS2_Field := 16#0#;
      --  unspecified
      Reserved_11_14 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Read-only.
      USBACTEP2      : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      NAKSTS2        : Boolean := False;
      --  Read-only.
      EPTYPE2        : DOEPCTL2_EPTYPE2_Field := 16#0#;
      SNP2           : Boolean := False;
      STALL2         : Boolean := False;
      --  unspecified
      Reserved_22_25 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Write-only.
      CNAK2          : Boolean := False;
      --  Write-only.
      DO_SNAK2       : Boolean := False;
      --  Write-only.
      DO_SETD0PID2   : Boolean := False;
      --  Write-only.
      DO_SETD1PID2   : Boolean := False;
      --  Read-only.
      EPDIS2         : Boolean := False;
      EPENA2         : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPCTL2_Register use record
      MPS2           at 0 range 0 .. 10;
      Reserved_11_14 at 0 range 11 .. 14;
      USBACTEP2      at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      NAKSTS2        at 0 range 17 .. 17;
      EPTYPE2        at 0 range 18 .. 19;
      SNP2           at 0 range 20 .. 20;
      STALL2         at 0 range 21 .. 21;
      Reserved_22_25 at 0 range 22 .. 25;
      CNAK2          at 0 range 26 .. 26;
      DO_SNAK2       at 0 range 27 .. 27;
      DO_SETD0PID2   at 0 range 28 .. 28;
      DO_SETD1PID2   at 0 range 29 .. 29;
      EPDIS2         at 0 range 30 .. 30;
      EPENA2         at 0 range 31 .. 31;
   end record;

   type DOEPINT2_Register is record
      XFERCOMPL2      : Boolean := False;
      EPDISBLD2       : Boolean := False;
      AHBERR2         : Boolean := False;
      SETUP2          : Boolean := False;
      OUTTKNEPDIS2    : Boolean := False;
      STSPHSERCVD2    : Boolean := False;
      BACK2BACKSETUP2 : Boolean := False;
      --  unspecified
      Reserved_7_7    : ESP32S3_Registers.Bit := 16#0#;
      OUTPKTERR2      : Boolean := False;
      BNAINTR2        : Boolean := False;
      --  unspecified
      Reserved_10_10  : ESP32S3_Registers.Bit := 16#0#;
      PKTDRPSTS2      : Boolean := False;
      BBLEERR2        : Boolean := False;
      NAKINTRPT2      : Boolean := False;
      NYEPINTRPT2     : Boolean := False;
      STUPPKTRCVD2    : Boolean := False;
      --  unspecified
      Reserved_16_31  : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPINT2_Register use record
      XFERCOMPL2      at 0 range 0 .. 0;
      EPDISBLD2       at 0 range 1 .. 1;
      AHBERR2         at 0 range 2 .. 2;
      SETUP2          at 0 range 3 .. 3;
      OUTTKNEPDIS2    at 0 range 4 .. 4;
      STSPHSERCVD2    at 0 range 5 .. 5;
      BACK2BACKSETUP2 at 0 range 6 .. 6;
      Reserved_7_7    at 0 range 7 .. 7;
      OUTPKTERR2      at 0 range 8 .. 8;
      BNAINTR2        at 0 range 9 .. 9;
      Reserved_10_10  at 0 range 10 .. 10;
      PKTDRPSTS2      at 0 range 11 .. 11;
      BBLEERR2        at 0 range 12 .. 12;
      NAKINTRPT2      at 0 range 13 .. 13;
      NYEPINTRPT2     at 0 range 14 .. 14;
      STUPPKTRCVD2    at 0 range 15 .. 15;
      Reserved_16_31  at 0 range 16 .. 31;
   end record;

   subtype DOEPTSIZ2_XFERSIZE2_Field is ESP32S3_Registers.UInt7;
   subtype DOEPTSIZ2_SUPCNT2_Field is ESP32S3_Registers.UInt2;

   type DOEPTSIZ2_Register is record
      XFERSIZE2      : DOEPTSIZ2_XFERSIZE2_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      PKTCNT2        : Boolean := False;
      --  unspecified
      Reserved_20_28 : ESP32S3_Registers.UInt9 := 16#0#;
      SUPCNT2        : DOEPTSIZ2_SUPCNT2_Field := 16#0#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPTSIZ2_Register use record
      XFERSIZE2      at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      PKTCNT2        at 0 range 19 .. 19;
      Reserved_20_28 at 0 range 20 .. 28;
      SUPCNT2        at 0 range 29 .. 30;
      Reserved_31_31 at 0 range 31 .. 31;
   end record;

   subtype DOEPCTL3_MPS3_Field is ESP32S3_Registers.UInt11;
   subtype DOEPCTL3_EPTYPE3_Field is ESP32S3_Registers.UInt2;

   type DOEPCTL3_Register is record
      --  Read-only.
      MPS3           : DOEPCTL3_MPS3_Field := 16#0#;
      --  unspecified
      Reserved_11_14 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Read-only.
      USBACTEP3      : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      NAKSTS3        : Boolean := False;
      --  Read-only.
      EPTYPE3        : DOEPCTL3_EPTYPE3_Field := 16#0#;
      SNP3           : Boolean := False;
      STALL3         : Boolean := False;
      --  unspecified
      Reserved_22_25 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Write-only.
      CNAK3          : Boolean := False;
      --  Write-only.
      DO_SNAK3       : Boolean := False;
      --  Write-only.
      DO_SETD0PID3   : Boolean := False;
      --  Write-only.
      DO_SETD1PID3   : Boolean := False;
      --  Read-only.
      EPDIS3         : Boolean := False;
      EPENA3         : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPCTL3_Register use record
      MPS3           at 0 range 0 .. 10;
      Reserved_11_14 at 0 range 11 .. 14;
      USBACTEP3      at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      NAKSTS3        at 0 range 17 .. 17;
      EPTYPE3        at 0 range 18 .. 19;
      SNP3           at 0 range 20 .. 20;
      STALL3         at 0 range 21 .. 21;
      Reserved_22_25 at 0 range 22 .. 25;
      CNAK3          at 0 range 26 .. 26;
      DO_SNAK3       at 0 range 27 .. 27;
      DO_SETD0PID3   at 0 range 28 .. 28;
      DO_SETD1PID3   at 0 range 29 .. 29;
      EPDIS3         at 0 range 30 .. 30;
      EPENA3         at 0 range 31 .. 31;
   end record;

   type DOEPINT3_Register is record
      XFERCOMPL3      : Boolean := False;
      EPDISBLD3       : Boolean := False;
      AHBERR3         : Boolean := False;
      SETUP3          : Boolean := False;
      OUTTKNEPDIS3    : Boolean := False;
      STSPHSERCVD3    : Boolean := False;
      BACK2BACKSETUP3 : Boolean := False;
      --  unspecified
      Reserved_7_7    : ESP32S3_Registers.Bit := 16#0#;
      OUTPKTERR3      : Boolean := False;
      BNAINTR3        : Boolean := False;
      --  unspecified
      Reserved_10_10  : ESP32S3_Registers.Bit := 16#0#;
      PKTDRPSTS3      : Boolean := False;
      BBLEERR3        : Boolean := False;
      NAKINTRPT3      : Boolean := False;
      NYEPINTRPT3     : Boolean := False;
      STUPPKTRCVD3    : Boolean := False;
      --  unspecified
      Reserved_16_31  : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPINT3_Register use record
      XFERCOMPL3      at 0 range 0 .. 0;
      EPDISBLD3       at 0 range 1 .. 1;
      AHBERR3         at 0 range 2 .. 2;
      SETUP3          at 0 range 3 .. 3;
      OUTTKNEPDIS3    at 0 range 4 .. 4;
      STSPHSERCVD3    at 0 range 5 .. 5;
      BACK2BACKSETUP3 at 0 range 6 .. 6;
      Reserved_7_7    at 0 range 7 .. 7;
      OUTPKTERR3      at 0 range 8 .. 8;
      BNAINTR3        at 0 range 9 .. 9;
      Reserved_10_10  at 0 range 10 .. 10;
      PKTDRPSTS3      at 0 range 11 .. 11;
      BBLEERR3        at 0 range 12 .. 12;
      NAKINTRPT3      at 0 range 13 .. 13;
      NYEPINTRPT3     at 0 range 14 .. 14;
      STUPPKTRCVD3    at 0 range 15 .. 15;
      Reserved_16_31  at 0 range 16 .. 31;
   end record;

   subtype DOEPTSIZ3_XFERSIZE3_Field is ESP32S3_Registers.UInt7;
   subtype DOEPTSIZ3_SUPCNT3_Field is ESP32S3_Registers.UInt2;

   type DOEPTSIZ3_Register is record
      XFERSIZE3      : DOEPTSIZ3_XFERSIZE3_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      PKTCNT3        : Boolean := False;
      --  unspecified
      Reserved_20_28 : ESP32S3_Registers.UInt9 := 16#0#;
      SUPCNT3        : DOEPTSIZ3_SUPCNT3_Field := 16#0#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPTSIZ3_Register use record
      XFERSIZE3      at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      PKTCNT3        at 0 range 19 .. 19;
      Reserved_20_28 at 0 range 20 .. 28;
      SUPCNT3        at 0 range 29 .. 30;
      Reserved_31_31 at 0 range 31 .. 31;
   end record;

   subtype DOEPCTL4_MPS4_Field is ESP32S3_Registers.UInt11;
   subtype DOEPCTL4_EPTYPE4_Field is ESP32S3_Registers.UInt2;

   type DOEPCTL4_Register is record
      --  Read-only.
      MPS4           : DOEPCTL4_MPS4_Field := 16#0#;
      --  unspecified
      Reserved_11_14 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Read-only.
      USBACTEP4      : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      NAKSTS4        : Boolean := False;
      --  Read-only.
      EPTYPE4        : DOEPCTL4_EPTYPE4_Field := 16#0#;
      SNP4           : Boolean := False;
      STALL4         : Boolean := False;
      --  unspecified
      Reserved_22_25 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Write-only.
      CNAK4          : Boolean := False;
      --  Write-only.
      DO_SNAK4       : Boolean := False;
      --  Write-only.
      DO_SETD0PID4   : Boolean := False;
      --  Write-only.
      DO_SETD1PID4   : Boolean := False;
      --  Read-only.
      EPDIS4         : Boolean := False;
      EPENA4         : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPCTL4_Register use record
      MPS4           at 0 range 0 .. 10;
      Reserved_11_14 at 0 range 11 .. 14;
      USBACTEP4      at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      NAKSTS4        at 0 range 17 .. 17;
      EPTYPE4        at 0 range 18 .. 19;
      SNP4           at 0 range 20 .. 20;
      STALL4         at 0 range 21 .. 21;
      Reserved_22_25 at 0 range 22 .. 25;
      CNAK4          at 0 range 26 .. 26;
      DO_SNAK4       at 0 range 27 .. 27;
      DO_SETD0PID4   at 0 range 28 .. 28;
      DO_SETD1PID4   at 0 range 29 .. 29;
      EPDIS4         at 0 range 30 .. 30;
      EPENA4         at 0 range 31 .. 31;
   end record;

   type DOEPINT4_Register is record
      XFERCOMPL4      : Boolean := False;
      EPDISBLD4       : Boolean := False;
      AHBERR4         : Boolean := False;
      SETUP4          : Boolean := False;
      OUTTKNEPDIS4    : Boolean := False;
      STSPHSERCVD4    : Boolean := False;
      BACK2BACKSETUP4 : Boolean := False;
      --  unspecified
      Reserved_7_7    : ESP32S3_Registers.Bit := 16#0#;
      OUTPKTERR4      : Boolean := False;
      BNAINTR4        : Boolean := False;
      --  unspecified
      Reserved_10_10  : ESP32S3_Registers.Bit := 16#0#;
      PKTDRPSTS4      : Boolean := False;
      BBLEERR4        : Boolean := False;
      NAKINTRPT4      : Boolean := False;
      NYEPINTRPT4     : Boolean := False;
      STUPPKTRCVD4    : Boolean := False;
      --  unspecified
      Reserved_16_31  : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPINT4_Register use record
      XFERCOMPL4      at 0 range 0 .. 0;
      EPDISBLD4       at 0 range 1 .. 1;
      AHBERR4         at 0 range 2 .. 2;
      SETUP4          at 0 range 3 .. 3;
      OUTTKNEPDIS4    at 0 range 4 .. 4;
      STSPHSERCVD4    at 0 range 5 .. 5;
      BACK2BACKSETUP4 at 0 range 6 .. 6;
      Reserved_7_7    at 0 range 7 .. 7;
      OUTPKTERR4      at 0 range 8 .. 8;
      BNAINTR4        at 0 range 9 .. 9;
      Reserved_10_10  at 0 range 10 .. 10;
      PKTDRPSTS4      at 0 range 11 .. 11;
      BBLEERR4        at 0 range 12 .. 12;
      NAKINTRPT4      at 0 range 13 .. 13;
      NYEPINTRPT4     at 0 range 14 .. 14;
      STUPPKTRCVD4    at 0 range 15 .. 15;
      Reserved_16_31  at 0 range 16 .. 31;
   end record;

   subtype DOEPTSIZ4_XFERSIZE4_Field is ESP32S3_Registers.UInt7;
   subtype DOEPTSIZ4_SUPCNT4_Field is ESP32S3_Registers.UInt2;

   type DOEPTSIZ4_Register is record
      XFERSIZE4      : DOEPTSIZ4_XFERSIZE4_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      PKTCNT4        : Boolean := False;
      --  unspecified
      Reserved_20_28 : ESP32S3_Registers.UInt9 := 16#0#;
      SUPCNT4        : DOEPTSIZ4_SUPCNT4_Field := 16#0#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPTSIZ4_Register use record
      XFERSIZE4      at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      PKTCNT4        at 0 range 19 .. 19;
      Reserved_20_28 at 0 range 20 .. 28;
      SUPCNT4        at 0 range 29 .. 30;
      Reserved_31_31 at 0 range 31 .. 31;
   end record;

   subtype DOEPCTL5_MPS5_Field is ESP32S3_Registers.UInt11;
   subtype DOEPCTL5_EPTYPE5_Field is ESP32S3_Registers.UInt2;

   type DOEPCTL5_Register is record
      --  Read-only.
      MPS5           : DOEPCTL5_MPS5_Field := 16#0#;
      --  unspecified
      Reserved_11_14 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Read-only.
      USBACTEP5      : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      NAKSTS5        : Boolean := False;
      --  Read-only.
      EPTYPE5        : DOEPCTL5_EPTYPE5_Field := 16#0#;
      SNP5           : Boolean := False;
      STALL5         : Boolean := False;
      --  unspecified
      Reserved_22_25 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Write-only.
      CNAK5          : Boolean := False;
      --  Write-only.
      DO_SNAK5       : Boolean := False;
      --  Write-only.
      DO_SETD0PID5   : Boolean := False;
      --  Write-only.
      DO_SETD1PID5   : Boolean := False;
      --  Read-only.
      EPDIS5         : Boolean := False;
      EPENA5         : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPCTL5_Register use record
      MPS5           at 0 range 0 .. 10;
      Reserved_11_14 at 0 range 11 .. 14;
      USBACTEP5      at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      NAKSTS5        at 0 range 17 .. 17;
      EPTYPE5        at 0 range 18 .. 19;
      SNP5           at 0 range 20 .. 20;
      STALL5         at 0 range 21 .. 21;
      Reserved_22_25 at 0 range 22 .. 25;
      CNAK5          at 0 range 26 .. 26;
      DO_SNAK5       at 0 range 27 .. 27;
      DO_SETD0PID5   at 0 range 28 .. 28;
      DO_SETD1PID5   at 0 range 29 .. 29;
      EPDIS5         at 0 range 30 .. 30;
      EPENA5         at 0 range 31 .. 31;
   end record;

   type DOEPINT5_Register is record
      XFERCOMPL5      : Boolean := False;
      EPDISBLD5       : Boolean := False;
      AHBERR5         : Boolean := False;
      SETUP5          : Boolean := False;
      OUTTKNEPDIS5    : Boolean := False;
      STSPHSERCVD5    : Boolean := False;
      BACK2BACKSETUP5 : Boolean := False;
      --  unspecified
      Reserved_7_7    : ESP32S3_Registers.Bit := 16#0#;
      OUTPKTERR5      : Boolean := False;
      BNAINTR5        : Boolean := False;
      --  unspecified
      Reserved_10_10  : ESP32S3_Registers.Bit := 16#0#;
      PKTDRPSTS5      : Boolean := False;
      BBLEERR5        : Boolean := False;
      NAKINTRPT5      : Boolean := False;
      NYEPINTRPT5     : Boolean := False;
      STUPPKTRCVD5    : Boolean := False;
      --  unspecified
      Reserved_16_31  : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPINT5_Register use record
      XFERCOMPL5      at 0 range 0 .. 0;
      EPDISBLD5       at 0 range 1 .. 1;
      AHBERR5         at 0 range 2 .. 2;
      SETUP5          at 0 range 3 .. 3;
      OUTTKNEPDIS5    at 0 range 4 .. 4;
      STSPHSERCVD5    at 0 range 5 .. 5;
      BACK2BACKSETUP5 at 0 range 6 .. 6;
      Reserved_7_7    at 0 range 7 .. 7;
      OUTPKTERR5      at 0 range 8 .. 8;
      BNAINTR5        at 0 range 9 .. 9;
      Reserved_10_10  at 0 range 10 .. 10;
      PKTDRPSTS5      at 0 range 11 .. 11;
      BBLEERR5        at 0 range 12 .. 12;
      NAKINTRPT5      at 0 range 13 .. 13;
      NYEPINTRPT5     at 0 range 14 .. 14;
      STUPPKTRCVD5    at 0 range 15 .. 15;
      Reserved_16_31  at 0 range 16 .. 31;
   end record;

   subtype DOEPTSIZ5_XFERSIZE5_Field is ESP32S3_Registers.UInt7;
   subtype DOEPTSIZ5_SUPCNT5_Field is ESP32S3_Registers.UInt2;

   type DOEPTSIZ5_Register is record
      XFERSIZE5      : DOEPTSIZ5_XFERSIZE5_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      PKTCNT5        : Boolean := False;
      --  unspecified
      Reserved_20_28 : ESP32S3_Registers.UInt9 := 16#0#;
      SUPCNT5        : DOEPTSIZ5_SUPCNT5_Field := 16#0#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPTSIZ5_Register use record
      XFERSIZE5      at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      PKTCNT5        at 0 range 19 .. 19;
      Reserved_20_28 at 0 range 20 .. 28;
      SUPCNT5        at 0 range 29 .. 30;
      Reserved_31_31 at 0 range 31 .. 31;
   end record;

   subtype DOEPCTL6_MPS6_Field is ESP32S3_Registers.UInt11;
   subtype DOEPCTL6_EPTYPE6_Field is ESP32S3_Registers.UInt2;

   type DOEPCTL6_Register is record
      --  Read-only.
      MPS6           : DOEPCTL6_MPS6_Field := 16#0#;
      --  unspecified
      Reserved_11_14 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Read-only.
      USBACTEP6      : Boolean := True;
      --  unspecified
      Reserved_16_16 : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only.
      NAKSTS6        : Boolean := False;
      --  Read-only.
      EPTYPE6        : DOEPCTL6_EPTYPE6_Field := 16#0#;
      SNP6           : Boolean := False;
      STALL6         : Boolean := False;
      --  unspecified
      Reserved_22_25 : ESP32S3_Registers.UInt4 := 16#0#;
      --  Write-only.
      CNAK6          : Boolean := False;
      --  Write-only.
      DO_SNAK6       : Boolean := False;
      --  Write-only.
      DO_SETD0PID6   : Boolean := False;
      --  Write-only.
      DO_SETD1PID6   : Boolean := False;
      --  Read-only.
      EPDIS6         : Boolean := False;
      EPENA6         : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPCTL6_Register use record
      MPS6           at 0 range 0 .. 10;
      Reserved_11_14 at 0 range 11 .. 14;
      USBACTEP6      at 0 range 15 .. 15;
      Reserved_16_16 at 0 range 16 .. 16;
      NAKSTS6        at 0 range 17 .. 17;
      EPTYPE6        at 0 range 18 .. 19;
      SNP6           at 0 range 20 .. 20;
      STALL6         at 0 range 21 .. 21;
      Reserved_22_25 at 0 range 22 .. 25;
      CNAK6          at 0 range 26 .. 26;
      DO_SNAK6       at 0 range 27 .. 27;
      DO_SETD0PID6   at 0 range 28 .. 28;
      DO_SETD1PID6   at 0 range 29 .. 29;
      EPDIS6         at 0 range 30 .. 30;
      EPENA6         at 0 range 31 .. 31;
   end record;

   type DOEPINT6_Register is record
      XFERCOMPL6      : Boolean := False;
      EPDISBLD6       : Boolean := False;
      AHBERR6         : Boolean := False;
      SETUP6          : Boolean := False;
      OUTTKNEPDIS6    : Boolean := False;
      STSPHSERCVD6    : Boolean := False;
      BACK2BACKSETUP6 : Boolean := False;
      --  unspecified
      Reserved_7_7    : ESP32S3_Registers.Bit := 16#0#;
      OUTPKTERR6      : Boolean := False;
      BNAINTR6        : Boolean := False;
      --  unspecified
      Reserved_10_10  : ESP32S3_Registers.Bit := 16#0#;
      PKTDRPSTS6      : Boolean := False;
      BBLEERR6        : Boolean := False;
      NAKINTRPT6      : Boolean := False;
      NYEPINTRPT6     : Boolean := False;
      STUPPKTRCVD6    : Boolean := False;
      --  unspecified
      Reserved_16_31  : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPINT6_Register use record
      XFERCOMPL6      at 0 range 0 .. 0;
      EPDISBLD6       at 0 range 1 .. 1;
      AHBERR6         at 0 range 2 .. 2;
      SETUP6          at 0 range 3 .. 3;
      OUTTKNEPDIS6    at 0 range 4 .. 4;
      STSPHSERCVD6    at 0 range 5 .. 5;
      BACK2BACKSETUP6 at 0 range 6 .. 6;
      Reserved_7_7    at 0 range 7 .. 7;
      OUTPKTERR6      at 0 range 8 .. 8;
      BNAINTR6        at 0 range 9 .. 9;
      Reserved_10_10  at 0 range 10 .. 10;
      PKTDRPSTS6      at 0 range 11 .. 11;
      BBLEERR6        at 0 range 12 .. 12;
      NAKINTRPT6      at 0 range 13 .. 13;
      NYEPINTRPT6     at 0 range 14 .. 14;
      STUPPKTRCVD6    at 0 range 15 .. 15;
      Reserved_16_31  at 0 range 16 .. 31;
   end record;

   subtype DOEPTSIZ6_XFERSIZE6_Field is ESP32S3_Registers.UInt7;
   subtype DOEPTSIZ6_SUPCNT6_Field is ESP32S3_Registers.UInt2;

   type DOEPTSIZ6_Register is record
      XFERSIZE6      : DOEPTSIZ6_XFERSIZE6_Field := 16#0#;
      --  unspecified
      Reserved_7_18  : ESP32S3_Registers.UInt12 := 16#0#;
      PKTCNT6        : Boolean := False;
      --  unspecified
      Reserved_20_28 : ESP32S3_Registers.UInt9 := 16#0#;
      SUPCNT6        : DOEPTSIZ6_SUPCNT6_Field := 16#0#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOEPTSIZ6_Register use record
      XFERSIZE6      at 0 range 0 .. 6;
      Reserved_7_18  at 0 range 7 .. 18;
      PKTCNT6        at 0 range 19 .. 19;
      Reserved_20_28 at 0 range 20 .. 28;
      SUPCNT6        at 0 range 29 .. 30;
      Reserved_31_31 at 0 range 31 .. 31;
   end record;

   type PCGCCTL_Register is record
      STOPPCLK       : Boolean := False;
      GATEHCLK       : Boolean := False;
      PWRCLMP        : Boolean := False;
      RSTPDWNMODULE  : Boolean := False;
      --  unspecified
      Reserved_4_5   : ESP32S3_Registers.UInt2 := 16#0#;
      --  Read-only.
      PHYSLEEP       : Boolean := False;
      --  Read-only.
      L1SUSPENDED    : Boolean := False;
      RESETAFTERSUSP : Boolean := False;
      --  unspecified
      Reserved_9_31  : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for PCGCCTL_Register use record
      STOPPCLK       at 0 range 0 .. 0;
      GATEHCLK       at 0 range 1 .. 1;
      PWRCLMP        at 0 range 2 .. 2;
      RSTPDWNMODULE  at 0 range 3 .. 3;
      Reserved_4_5   at 0 range 4 .. 5;
      PHYSLEEP       at 0 range 6 .. 6;
      L1SUSPENDED    at 0 range 7 .. 7;
      RESETAFTERSUSP at 0 range 8 .. 8;
      Reserved_9_31  at 0 range 9 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  USB OTG (On-The-Go)
   type USB0_Peripheral is record
      GOTGCTL    : aliased GOTGCTL_Register;
      GOTGINT    : aliased GOTGINT_Register;
      GAHBCFG    : aliased GAHBCFG_Register;
      GUSBCFG    : aliased GUSBCFG_Register;
      GRSTCTL    : aliased GRSTCTL_Register;
      GINTSTS    : aliased GINTSTS_Register;
      GINTMSK    : aliased GINTMSK_Register;
      GRXSTSR    : aliased GRXSTSR_Register;
      GRXSTSP    : aliased GRXSTSP_Register;
      GRXFSIZ    : aliased GRXFSIZ_Register;
      GNPTXFSIZ  : aliased GNPTXFSIZ_Register;
      GNPTXSTS   : aliased GNPTXSTS_Register;
      GSNPSID    : aliased ESP32S3_Registers.UInt32;
      GHWCFG1    : aliased ESP32S3_Registers.UInt32;
      GHWCFG2    : aliased GHWCFG2_Register;
      GHWCFG3    : aliased GHWCFG3_Register;
      GHWCFG4    : aliased GHWCFG4_Register;
      GDFIFOCFG  : aliased GDFIFOCFG_Register;
      HPTXFSIZ   : aliased HPTXFSIZ_Register;
      DIEPTXF1   : aliased DIEPTXF1_Register;
      DIEPTXF2   : aliased DIEPTXF2_Register;
      DIEPTXF3   : aliased DIEPTXF3_Register;
      DIEPTXF4   : aliased DIEPTXF4_Register;
      HCFG       : aliased HCFG_Register;
      HFIR       : aliased HFIR_Register;
      HFNUM      : aliased HFNUM_Register;
      HPTXSTS    : aliased HPTXSTS_Register;
      HAINT      : aliased HAINT_Register;
      HAINTMSK   : aliased HAINTMSK_Register;
      HFLBADDR   : aliased ESP32S3_Registers.UInt32;
      HPRT       : aliased HPRT_Register;
      HCCHAR0    : aliased HCCHAR0_Register;
      HCINT0     : aliased HCINT0_Register;
      HCINTMSK0  : aliased HCINTMSK0_Register;
      HCTSIZ0    : aliased HCTSIZ0_Register;
      HCDMA0     : aliased ESP32S3_Registers.UInt32;
      HCDMAB0    : aliased ESP32S3_Registers.UInt32;
      HCCHAR1    : aliased HCCHAR1_Register;
      HCINT1     : aliased HCINT1_Register;
      HCINTMSK1  : aliased HCINTMSK1_Register;
      HCTSIZ1    : aliased HCTSIZ1_Register;
      HCDMA1     : aliased ESP32S3_Registers.UInt32;
      HCDMAB1    : aliased ESP32S3_Registers.UInt32;
      HCCHAR2    : aliased HCCHAR2_Register;
      HCINT2     : aliased HCINT2_Register;
      HCINTMSK2  : aliased HCINTMSK2_Register;
      HCTSIZ2    : aliased HCTSIZ2_Register;
      HCDMA2     : aliased ESP32S3_Registers.UInt32;
      HCDMAB2    : aliased ESP32S3_Registers.UInt32;
      HCCHAR3    : aliased HCCHAR3_Register;
      HCINT3     : aliased HCINT3_Register;
      HCINTMSK3  : aliased HCINTMSK3_Register;
      HCTSIZ3    : aliased HCTSIZ3_Register;
      HCDMA3     : aliased ESP32S3_Registers.UInt32;
      HCDMAB3    : aliased ESP32S3_Registers.UInt32;
      HCCHAR4    : aliased HCCHAR4_Register;
      HCINT4     : aliased HCINT4_Register;
      HCINTMSK4  : aliased HCINTMSK4_Register;
      HCTSIZ4    : aliased HCTSIZ4_Register;
      HCDMA4     : aliased ESP32S3_Registers.UInt32;
      HCDMAB4    : aliased ESP32S3_Registers.UInt32;
      HCCHAR5    : aliased HCCHAR5_Register;
      HCINT5     : aliased HCINT5_Register;
      HCINTMSK5  : aliased HCINTMSK5_Register;
      HCTSIZ5    : aliased HCTSIZ5_Register;
      HCDMA5     : aliased ESP32S3_Registers.UInt32;
      HCDMAB5    : aliased ESP32S3_Registers.UInt32;
      HCCHAR6    : aliased HCCHAR6_Register;
      HCINT6     : aliased HCINT6_Register;
      HCINTMSK6  : aliased HCINTMSK6_Register;
      HCTSIZ6    : aliased HCTSIZ6_Register;
      HCDMA6     : aliased ESP32S3_Registers.UInt32;
      HCDMAB6    : aliased ESP32S3_Registers.UInt32;
      HCCHAR7    : aliased HCCHAR7_Register;
      HCINT7     : aliased HCINT7_Register;
      HCINTMSK7  : aliased HCINTMSK7_Register;
      HCTSIZ7    : aliased HCTSIZ7_Register;
      HCDMA7     : aliased ESP32S3_Registers.UInt32;
      HCDMAB7    : aliased ESP32S3_Registers.UInt32;
      DCFG       : aliased DCFG_Register;
      DCTL       : aliased DCTL_Register;
      DSTS       : aliased DSTS_Register;
      DIEPMSK    : aliased DIEPMSK_Register;
      DOEPMSK    : aliased DOEPMSK_Register;
      DAINT      : aliased DAINT_Register;
      DAINTMSK   : aliased DAINTMSK_Register;
      DVBUSDIS   : aliased DVBUSDIS_Register;
      DVBUSPULSE : aliased DVBUSPULSE_Register;
      DTHRCTL    : aliased DTHRCTL_Register;
      DIEPEMPMSK : aliased DIEPEMPMSK_Register;
      DIEPCTL0   : aliased DIEPCTL0_Register;
      DIEPINT0   : aliased DIEPINT0_Register;
      DIEPTSIZ0  : aliased DIEPTSIZ0_Register;
      DIEPDMA0   : aliased ESP32S3_Registers.UInt32;
      DTXFSTS0   : aliased DTXFSTS0_Register;
      DIEPDMAB0  : aliased ESP32S3_Registers.UInt32;
      DIEPCTL1   : aliased DIEPCTL1_Register;
      DIEPINT1   : aliased DIEPINT1_Register;
      DIEPTSIZ1  : aliased DIEPTSIZ1_Register;
      DIEPDMA1   : aliased ESP32S3_Registers.UInt32;
      DTXFSTS1   : aliased DTXFSTS1_Register;
      DIEPDMAB1  : aliased ESP32S3_Registers.UInt32;
      DIEPCTL2   : aliased DIEPCTL2_Register;
      DIEPINT2   : aliased DIEPINT2_Register;
      DIEPTSIZ2  : aliased DIEPTSIZ2_Register;
      DIEPDMA2   : aliased ESP32S3_Registers.UInt32;
      DTXFSTS2   : aliased DTXFSTS2_Register;
      DIEPDMAB2  : aliased ESP32S3_Registers.UInt32;
      DIEPCTL3   : aliased DIEPCTL3_Register;
      DIEPINT3   : aliased DIEPINT3_Register;
      DIEPTSIZ3  : aliased DIEPTSIZ3_Register;
      DIEPDMA3   : aliased ESP32S3_Registers.UInt32;
      DTXFSTS3   : aliased DTXFSTS3_Register;
      DIEPDMAB3  : aliased ESP32S3_Registers.UInt32;
      DIEPCTL4   : aliased DIEPCTL4_Register;
      DIEPINT4   : aliased DIEPINT4_Register;
      DIEPTSIZ4  : aliased DIEPTSIZ4_Register;
      DIEPDMA4   : aliased ESP32S3_Registers.UInt32;
      DTXFSTS4   : aliased DTXFSTS4_Register;
      DIEPDMAB4  : aliased ESP32S3_Registers.UInt32;
      DIEPCTL5   : aliased DIEPCTL5_Register;
      DIEPINT5   : aliased DIEPINT5_Register;
      DIEPTSIZ5  : aliased DIEPTSIZ5_Register;
      DIEPDMA5   : aliased ESP32S3_Registers.UInt32;
      DTXFSTS5   : aliased DTXFSTS5_Register;
      DIEPDMAB5  : aliased ESP32S3_Registers.UInt32;
      DIEPCTL6   : aliased DIEPCTL6_Register;
      DIEPINT6   : aliased DIEPINT6_Register;
      DIEPTSIZ6  : aliased DIEPTSIZ6_Register;
      DIEPDMA6   : aliased ESP32S3_Registers.UInt32;
      DTXFSTS6   : aliased DTXFSTS6_Register;
      DIEPDMAB6  : aliased ESP32S3_Registers.UInt32;
      DOEPCTL0   : aliased DOEPCTL0_Register;
      DOEPINT0   : aliased DOEPINT0_Register;
      DOEPTSIZ0  : aliased DOEPTSIZ0_Register;
      DOEPDMA0   : aliased ESP32S3_Registers.UInt32;
      DOEPDMAB0  : aliased ESP32S3_Registers.UInt32;
      DOEPCTL1   : aliased DOEPCTL1_Register;
      DOEPINT1   : aliased DOEPINT1_Register;
      DOEPTSIZ1  : aliased DOEPTSIZ1_Register;
      DOEPDMA1   : aliased ESP32S3_Registers.UInt32;
      DOEPDMAB1  : aliased ESP32S3_Registers.UInt32;
      DOEPCTL2   : aliased DOEPCTL2_Register;
      DOEPINT2   : aliased DOEPINT2_Register;
      DOEPTSIZ2  : aliased DOEPTSIZ2_Register;
      DOEPDMA2   : aliased ESP32S3_Registers.UInt32;
      DOEPDMAB2  : aliased ESP32S3_Registers.UInt32;
      DOEPCTL3   : aliased DOEPCTL3_Register;
      DOEPINT3   : aliased DOEPINT3_Register;
      DOEPTSIZ3  : aliased DOEPTSIZ3_Register;
      DOEPDMA3   : aliased ESP32S3_Registers.UInt32;
      DOEPDMAB3  : aliased ESP32S3_Registers.UInt32;
      DOEPCTL4   : aliased DOEPCTL4_Register;
      DOEPINT4   : aliased DOEPINT4_Register;
      DOEPTSIZ4  : aliased DOEPTSIZ4_Register;
      DOEPDMA4   : aliased ESP32S3_Registers.UInt32;
      DOEPDMAB4  : aliased ESP32S3_Registers.UInt32;
      DOEPCTL5   : aliased DOEPCTL5_Register;
      DOEPINT5   : aliased DOEPINT5_Register;
      DOEPTSIZ5  : aliased DOEPTSIZ5_Register;
      DOEPDMA5   : aliased ESP32S3_Registers.UInt32;
      DOEPDMAB5  : aliased ESP32S3_Registers.UInt32;
      DOEPCTL6   : aliased DOEPCTL6_Register;
      DOEPINT6   : aliased DOEPINT6_Register;
      DOEPTSIZ6  : aliased DOEPTSIZ6_Register;
      DOEPDMA6   : aliased ESP32S3_Registers.UInt32;
      DOEPDMAB6  : aliased ESP32S3_Registers.UInt32;
      PCGCCTL    : aliased PCGCCTL_Register;
   end record
     with Volatile;

   for USB0_Peripheral use record
      GOTGCTL    at 16#0# range 0 .. 31;
      GOTGINT    at 16#4# range 0 .. 31;
      GAHBCFG    at 16#8# range 0 .. 31;
      GUSBCFG    at 16#C# range 0 .. 31;
      GRSTCTL    at 16#10# range 0 .. 31;
      GINTSTS    at 16#14# range 0 .. 31;
      GINTMSK    at 16#18# range 0 .. 31;
      GRXSTSR    at 16#1C# range 0 .. 31;
      GRXSTSP    at 16#20# range 0 .. 31;
      GRXFSIZ    at 16#24# range 0 .. 31;
      GNPTXFSIZ  at 16#28# range 0 .. 31;
      GNPTXSTS   at 16#2C# range 0 .. 31;
      GSNPSID    at 16#40# range 0 .. 31;
      GHWCFG1    at 16#44# range 0 .. 31;
      GHWCFG2    at 16#48# range 0 .. 31;
      GHWCFG3    at 16#4C# range 0 .. 31;
      GHWCFG4    at 16#50# range 0 .. 31;
      GDFIFOCFG  at 16#5C# range 0 .. 31;
      HPTXFSIZ   at 16#100# range 0 .. 31;
      DIEPTXF1   at 16#104# range 0 .. 31;
      DIEPTXF2   at 16#108# range 0 .. 31;
      DIEPTXF3   at 16#10C# range 0 .. 31;
      DIEPTXF4   at 16#110# range 0 .. 31;
      HCFG       at 16#400# range 0 .. 31;
      HFIR       at 16#404# range 0 .. 31;
      HFNUM      at 16#408# range 0 .. 31;
      HPTXSTS    at 16#410# range 0 .. 31;
      HAINT      at 16#414# range 0 .. 31;
      HAINTMSK   at 16#418# range 0 .. 31;
      HFLBADDR   at 16#41C# range 0 .. 31;
      HPRT       at 16#440# range 0 .. 31;
      HCCHAR0    at 16#500# range 0 .. 31;
      HCINT0     at 16#508# range 0 .. 31;
      HCINTMSK0  at 16#50C# range 0 .. 31;
      HCTSIZ0    at 16#510# range 0 .. 31;
      HCDMA0     at 16#514# range 0 .. 31;
      HCDMAB0    at 16#51C# range 0 .. 31;
      HCCHAR1    at 16#520# range 0 .. 31;
      HCINT1     at 16#528# range 0 .. 31;
      HCINTMSK1  at 16#52C# range 0 .. 31;
      HCTSIZ1    at 16#530# range 0 .. 31;
      HCDMA1     at 16#534# range 0 .. 31;
      HCDMAB1    at 16#53C# range 0 .. 31;
      HCCHAR2    at 16#540# range 0 .. 31;
      HCINT2     at 16#548# range 0 .. 31;
      HCINTMSK2  at 16#54C# range 0 .. 31;
      HCTSIZ2    at 16#550# range 0 .. 31;
      HCDMA2     at 16#554# range 0 .. 31;
      HCDMAB2    at 16#55C# range 0 .. 31;
      HCCHAR3    at 16#560# range 0 .. 31;
      HCINT3     at 16#568# range 0 .. 31;
      HCINTMSK3  at 16#56C# range 0 .. 31;
      HCTSIZ3    at 16#570# range 0 .. 31;
      HCDMA3     at 16#574# range 0 .. 31;
      HCDMAB3    at 16#57C# range 0 .. 31;
      HCCHAR4    at 16#580# range 0 .. 31;
      HCINT4     at 16#588# range 0 .. 31;
      HCINTMSK4  at 16#58C# range 0 .. 31;
      HCTSIZ4    at 16#590# range 0 .. 31;
      HCDMA4     at 16#594# range 0 .. 31;
      HCDMAB4    at 16#59C# range 0 .. 31;
      HCCHAR5    at 16#5A0# range 0 .. 31;
      HCINT5     at 16#5A8# range 0 .. 31;
      HCINTMSK5  at 16#5AC# range 0 .. 31;
      HCTSIZ5    at 16#5B0# range 0 .. 31;
      HCDMA5     at 16#5B4# range 0 .. 31;
      HCDMAB5    at 16#5BC# range 0 .. 31;
      HCCHAR6    at 16#5C0# range 0 .. 31;
      HCINT6     at 16#5C8# range 0 .. 31;
      HCINTMSK6  at 16#5CC# range 0 .. 31;
      HCTSIZ6    at 16#5D0# range 0 .. 31;
      HCDMA6     at 16#5D4# range 0 .. 31;
      HCDMAB6    at 16#5DC# range 0 .. 31;
      HCCHAR7    at 16#5E0# range 0 .. 31;
      HCINT7     at 16#5E8# range 0 .. 31;
      HCINTMSK7  at 16#5EC# range 0 .. 31;
      HCTSIZ7    at 16#5F0# range 0 .. 31;
      HCDMA7     at 16#5F4# range 0 .. 31;
      HCDMAB7    at 16#5FC# range 0 .. 31;
      DCFG       at 16#800# range 0 .. 31;
      DCTL       at 16#804# range 0 .. 31;
      DSTS       at 16#808# range 0 .. 31;
      DIEPMSK    at 16#810# range 0 .. 31;
      DOEPMSK    at 16#814# range 0 .. 31;
      DAINT      at 16#818# range 0 .. 31;
      DAINTMSK   at 16#81C# range 0 .. 31;
      DVBUSDIS   at 16#828# range 0 .. 31;
      DVBUSPULSE at 16#82C# range 0 .. 31;
      DTHRCTL    at 16#830# range 0 .. 31;
      DIEPEMPMSK at 16#834# range 0 .. 31;
      DIEPCTL0   at 16#900# range 0 .. 31;
      DIEPINT0   at 16#908# range 0 .. 31;
      DIEPTSIZ0  at 16#910# range 0 .. 31;
      DIEPDMA0   at 16#914# range 0 .. 31;
      DTXFSTS0   at 16#918# range 0 .. 31;
      DIEPDMAB0  at 16#91C# range 0 .. 31;
      DIEPCTL1   at 16#920# range 0 .. 31;
      DIEPINT1   at 16#928# range 0 .. 31;
      DIEPTSIZ1  at 16#930# range 0 .. 31;
      DIEPDMA1   at 16#934# range 0 .. 31;
      DTXFSTS1   at 16#938# range 0 .. 31;
      DIEPDMAB1  at 16#93C# range 0 .. 31;
      DIEPCTL2   at 16#940# range 0 .. 31;
      DIEPINT2   at 16#948# range 0 .. 31;
      DIEPTSIZ2  at 16#950# range 0 .. 31;
      DIEPDMA2   at 16#954# range 0 .. 31;
      DTXFSTS2   at 16#958# range 0 .. 31;
      DIEPDMAB2  at 16#95C# range 0 .. 31;
      DIEPCTL3   at 16#960# range 0 .. 31;
      DIEPINT3   at 16#968# range 0 .. 31;
      DIEPTSIZ3  at 16#970# range 0 .. 31;
      DIEPDMA3   at 16#974# range 0 .. 31;
      DTXFSTS3   at 16#978# range 0 .. 31;
      DIEPDMAB3  at 16#97C# range 0 .. 31;
      DIEPCTL4   at 16#980# range 0 .. 31;
      DIEPINT4   at 16#988# range 0 .. 31;
      DIEPTSIZ4  at 16#990# range 0 .. 31;
      DIEPDMA4   at 16#994# range 0 .. 31;
      DTXFSTS4   at 16#998# range 0 .. 31;
      DIEPDMAB4  at 16#99C# range 0 .. 31;
      DIEPCTL5   at 16#9A0# range 0 .. 31;
      DIEPINT5   at 16#9A8# range 0 .. 31;
      DIEPTSIZ5  at 16#9B0# range 0 .. 31;
      DIEPDMA5   at 16#9B4# range 0 .. 31;
      DTXFSTS5   at 16#9B8# range 0 .. 31;
      DIEPDMAB5  at 16#9BC# range 0 .. 31;
      DIEPCTL6   at 16#9C0# range 0 .. 31;
      DIEPINT6   at 16#9C8# range 0 .. 31;
      DIEPTSIZ6  at 16#9D0# range 0 .. 31;
      DIEPDMA6   at 16#9D4# range 0 .. 31;
      DTXFSTS6   at 16#9D8# range 0 .. 31;
      DIEPDMAB6  at 16#9DC# range 0 .. 31;
      DOEPCTL0   at 16#B00# range 0 .. 31;
      DOEPINT0   at 16#B08# range 0 .. 31;
      DOEPTSIZ0  at 16#B10# range 0 .. 31;
      DOEPDMA0   at 16#B14# range 0 .. 31;
      DOEPDMAB0  at 16#B1C# range 0 .. 31;
      DOEPCTL1   at 16#B20# range 0 .. 31;
      DOEPINT1   at 16#B28# range 0 .. 31;
      DOEPTSIZ1  at 16#B30# range 0 .. 31;
      DOEPDMA1   at 16#B34# range 0 .. 31;
      DOEPDMAB1  at 16#B3C# range 0 .. 31;
      DOEPCTL2   at 16#B40# range 0 .. 31;
      DOEPINT2   at 16#B48# range 0 .. 31;
      DOEPTSIZ2  at 16#B50# range 0 .. 31;
      DOEPDMA2   at 16#B54# range 0 .. 31;
      DOEPDMAB2  at 16#B5C# range 0 .. 31;
      DOEPCTL3   at 16#B60# range 0 .. 31;
      DOEPINT3   at 16#B68# range 0 .. 31;
      DOEPTSIZ3  at 16#B70# range 0 .. 31;
      DOEPDMA3   at 16#B74# range 0 .. 31;
      DOEPDMAB3  at 16#B7C# range 0 .. 31;
      DOEPCTL4   at 16#B80# range 0 .. 31;
      DOEPINT4   at 16#B88# range 0 .. 31;
      DOEPTSIZ4  at 16#B90# range 0 .. 31;
      DOEPDMA4   at 16#B94# range 0 .. 31;
      DOEPDMAB4  at 16#B9C# range 0 .. 31;
      DOEPCTL5   at 16#BA0# range 0 .. 31;
      DOEPINT5   at 16#BA8# range 0 .. 31;
      DOEPTSIZ5  at 16#BB0# range 0 .. 31;
      DOEPDMA5   at 16#BB4# range 0 .. 31;
      DOEPDMAB5  at 16#BBC# range 0 .. 31;
      DOEPCTL6   at 16#BC0# range 0 .. 31;
      DOEPINT6   at 16#BC8# range 0 .. 31;
      DOEPTSIZ6  at 16#BD0# range 0 .. 31;
      DOEPDMA6   at 16#BD4# range 0 .. 31;
      DOEPDMAB6  at 16#BDC# range 0 .. 31;
      PCGCCTL    at 16#E00# range 0 .. 31;
   end record;

   --  USB OTG (On-The-Go)
   USB0_Periph : aliased USB0_Peripheral
     with Import, Address => USB0_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.USB;
