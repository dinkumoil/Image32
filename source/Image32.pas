unit Image32;

(*******************************************************************************
* Author    :  Angus Johnson                                                   *
* Version   :  2.12                                                            *
* Date      :  14 March 2021                                                   *
* Website   :  http://www.angusj.com                                           *
* Copyright :  Angus Johnson 2019-2021                                         *
* Purpose   :  The core module of the Image32 library                          *
* License   :  http://www.boost.org/LICENSE_1_0.txt                            *
*******************************************************************************)

interface

{$I Image32.inc}

uses
  {$IFDEF MSWINDOWS} Windows,{$ENDIF} Types, SysUtils, Classes,
  {$IFDEF XPLAT_GENERICS} Generics.Collections,
  Generics.Defaults, Character,
  {$ENDIF} {$IFDEF UITYPES} UITypes,{$ENDIF} Math;

type
  TRect = Types.TRect;
  TColor32 = type Cardinal;
  TPointD = record X, Y: double; end;

const
  clNone32     = TColor32($00000000);
  clAqua32     = TColor32($FF00FFFF);
  clBlack32    = TColor32($FF000000);
  clBlue32     = TColor32($FF0000FF);
  clFuchsia32  = TColor32($FFFF00FF);
  clGray32     = TColor32($FF7F7F7F);
  clGreen32    = TColor32($FF008000);
  clLime32     = TColor32($FF00FF00);
  clMaroon32   = TColor32($FF800000);
  clNavy32     = TColor32($FF000080);
  clOlive32    = TColor32($FF7F7F00);
  clOrange32   = TColor32($FFFF7F00);
  clPurple32   = TColor32($FF7F00FF);
  clRed32      = TColor32($FFFF0000);
  clSilver32   = TColor32($FFC0C0C0);
  clTeal32     = TColor32($FF007F7F);
  clWhite32    = TColor32($FFFFFFFF);
  clYellow32   = TColor32($FFFFFF00);

{$IFDEF ZEROBASEDSTR}
  {$ZEROBASEDSTRINGS OFF}
{$ENDIF}

{$IFNDEF MSWINDOWS}
  RT_BITMAP = PChar(2);
{$ENDIF}

type
  TClipboardPriority = (cpLow, cpMedium, cpHigh);

  PColor32 = ^TColor32;
  TArrayOfColor32 = array of TColor32;
  TArrayOfArrayOfColor32 = array of TArrayOfColor32;
  TArrayOfInteger = array of Integer;
  TArrayOfWord = array of WORD;
  TArrayOfByte = array of Byte;

  TImage32 = class;
  TImageFormatClass = class of TImageFormat;

  //TImageFormat: Abstract base class for loading and saving images in TImage32.<br>
  //This class is overridden to provide support for separate
  //file storage formats (eg BMP, PNG, GIF & JPG).<br>
  //Derived classes register with TImage32 using TImage32.RegisterImageFormatClass.
  TImageFormat = class
    procedure SaveToStream(stream: TStream; img32: TImage32); virtual; abstract;
    function SaveToFile(const filename: string; img32: TImage32): Boolean; virtual;
    function LoadFromStream(stream: TStream; img32: TImage32): Boolean; virtual; abstract;
    function LoadFromFile(const filename: string; img32: TImage32): Boolean; virtual;
    class function CanCopyToClipboard: Boolean; virtual;
    class function CopyToClipboard(img32: TImage32): Boolean; virtual; abstract;
    class function CanPasteFromClipboard: Boolean; virtual; abstract;
    class function PasteFromClipboard(img32: TImage32): Boolean; virtual; abstract;
  end;

  TBlendFunction = function(bgColor, fgColor: TColor32): TColor32;

  TCompareFunction = function(master, current: TColor32; data: integer): Boolean;
  TCompareFunctionEx = function(master, current: TColor32): Byte;

  TTileFillStyle = (tfsRepeat, tfsMirrorHorz, tfsMirrorVert, tfsRotate180);

  TImage32 = class
  private
    fWidth: integer;
    fHeight: Integer;
    fAntiAliase: Boolean;
    fIsPremultiplied: Boolean;
    fColorCount: integer;
    fPixels: TArrayOfColor32;
    fOnChange: TNotifyEvent;
    fOnResize: TNotifyEvent;
    fUpdateCnt: integer;
    function GetPixel(x,y: Integer): TColor32;
    procedure SetPixel(x,y: Integer; color: TColor32);
    function GetIsBlank: Boolean;
    function GetIsEmpty: Boolean;
    function GetPixelBase: PColor32;
    function GetPixelRow(row: Integer): PColor32;
    procedure InternalStretchResizeFast(newWidth, newHeight: Integer);
    procedure InternalStretchResizeAA(newWidth, newHeight: Integer);
    procedure RotateLeft90;
    procedure RotateRight90;
    procedure Rotate180;
    function GetColorCount: Integer;
    function GetHasTransparency: Boolean;
    function GetBounds: TRect;
    function GetMidPoint: TPointD;
  protected
    function CopyPixels(rec: TRect): TArrayOfColor32;
    //CopyInternal: Internal routine (has no scaling or bounds checking)
    procedure CopyInternal(src: TImage32;
      const srcRec, dstRec: TRect; blendFunc: TBlendFunction);
    procedure Changed; virtual;
    procedure Resized; virtual;
    property UpdateCount: integer read fUpdateCnt;
  public
    constructor Create(width: Integer = 0; height: Integer = 0); overload;
    constructor Create(src: TImage32); overload;
    constructor Create(src: TImage32; const srcRec: TRect); overload;
    destructor Destroy; override;
    procedure BeginUpdate;
    procedure EndUpdate;

    procedure Assign(src: TImage32);
    procedure AssignTo(dst: TImage32);
    //SetSize: Erases any current image, and fills with the specified color.
    procedure SetSize(newWidth, newHeight: Integer; color: TColor32 = 0);
    //Resize: is similar to Scale() in that it won't eraze the existing
    //image. Depending on the stretchImage parameter it will either stretch
    //or crop the image. Don't confuse Resize() with SetSize(), as the latter
    //does erase the image.
    procedure Resize(newWidth, newHeight: Integer; stretchImage: Boolean = true);
    //ScaleToFit: The new image will be scaled to fit within 'rec'
    procedure ScaleToFit(width, height: integer);
    //ScaleToFitCentered: The new image will be scaled and also centred
    procedure ScaleToFitCentered(width, height: integer);
    procedure Scale(s: single); overload;
    procedure Scale(sx, sy: single); overload;

    function Copy(src: TImage32; srcRec, dstRec: TRect): Boolean;
    //CopyBlend: Copies part or all of another TImage32 image (src).
    //If no blend function is provided, then the pixels in src's srcRec
    //simply replace whatever is in 'dstRec'. If a blend function is provided,
    //then that functions determines how the image from src will be blended
    //with the current image. Also the image from src's srcRec will be
    //stretched if necessary to fit into dstRec.
    function CopyBlend(src: TImage32; srcRec, dstRec: TRect;
      blendFunc: TBlendFunction = nil): Boolean;

{$IFDEF MSWINDOWS}
    //CopyFromDC: Copies an image from a Windows device context, erasing
    //any current image in TImage32. (eg copying from TBitmap.canvas.handle)
    procedure CopyFromDC(srcDc: HDC; const srcRect: TRect);
    //CopyToDc: Copies the image into a Windows device context
    procedure CopyToDc(dstDc: HDC; x: Integer = 0; y: Integer = 0;
      transparent: Boolean = true; bkColor: TColor32 = clNone32); overload;
    procedure CopyToDc(const srcRect: TRect; dstDc: HDC;
      x: Integer = 0; y: Integer = 0; transparent: Boolean = true;
      bkColor: TColor32 = clNone32); overload;
    procedure CopyToDc(const srcRect, dstRect: TRect; dstDc: HDC;
      transparent: Boolean = true;
      bkColor: TColor32 = clNone32); overload;
{$ENDIF}
    function CopyToClipBoard: Boolean;
    class function CanPasteFromClipBoard: Boolean;
    function PasteFromClipBoard: Boolean;
    procedure Crop(const rec: TRect);
    //SetBackgroundColor: Assumes the current image is semi-transparent.
    procedure SetBackgroundColor(bgColor: TColor32);
    //Clear: Fills the entire image with the specified color
    procedure Clear(color: TColor32 = 0);
    procedure FillRect(rec: TRect; color: TColor32);
    procedure ConvertToBoolMask(reference: TColor32;
      tolerance: integer; colorFunc: TCompareFunction;
      maskBg: TColor32 = clWhite32; maskFg: TColor32 = clBlack32);
    procedure ConvertToAlphaMask(reference: TColor32;
      colorFunc: TCompareFunctionEx);
    procedure FlipVertical;
    procedure FlipHorizontal;
    procedure PreMultiply;
    //SetAlpha: Sets 'alpha' to the alpha byte of every pixel in the image
    procedure SetAlpha(alpha: Byte);
    //SetRGB: Sets the RGB channels leaving the alpha channel unchanged
    procedure SetRGB(rgbColor: TColor32);
    //Grayscale: Only changes color channels. The alpha channel is untouched.
    procedure Grayscale;
    procedure InvertColors;
    procedure InvertAlphas;
    procedure Tile(newWidth, newHeight: integer;
      style: TTileFillStyle = tfsRepeat);
    procedure AdjustHue(percent: Integer);         //ie +/- 100%
    procedure AdjustLuminance(percent: Integer);   //ie +/- 100%
    procedure AdjustSaturation(percent: Integer);  //ie +/- 100%

    //CropTransparentPixels: Trims transparent edges until each edge contains
    //at least one opaque or semi-opaque pixel.
    function CropTransparentPixels: TRect;
    procedure Rotate(angleRads: double);
    //RotateRect: Rotates part of an image, but also clips those parts of the
    //rotated image that fall outside rec. The eraseColor parameter indicates
    //the color to fill those uncovered pixels in rec following rotation.
    procedure RotateRect(const rec: TRect;
      angleRads: single; eraseColor: TColor32 = 0);
    procedure Skew(dx,dy: double);

    //ScaleAlpha: Scales the alpha byte of every pixel by the specified amount.
    procedure ScaleAlpha(scale: double);
    //RegisterImageFormatClass: Registers a TImageFormatClass with TImage32 and
    //associates it with a specific 3 character file extension (eg BMP).
    class procedure RegisterImageFormatClass(ext: string;
      bm32ExClass: TImageFormatClass; clipPriority: TClipboardPriority);
    class function GetImageFormatClass(const ext: string): TImageFormatClass;
    //GetExtFromImageStream: Returns the stream's format as a three character
    //string (eg BMP, PNG, JPG).
    class function GetExtFromImageStream(stream: TStream): string;
    //IsRegisteredFormat: Returns true if 'ext' (a three character string) is
    //registered with TImage32 as a storage format.<br> See also
    //TImage32.RegisterImageFormatClass.
    class function IsRegisteredFormat(const ext: string): Boolean;
    //SaveToFile: Will fail if filename's extension hasn't been registered
    //as a supported storage format.<br>See TImage32.RegisterImageFormatClass.
    function SaveToFile(filename: string): Boolean;
    function SaveToStream(stream: TStream; const FmtExt: string): Boolean;
    //LoadFromFile: Requires a TImageFormat registered with TImage32 that's
    //associated with filename's extension.<br>
    //See TImage32.RegisterImageFormatClass.
    function LoadFromFile(const filename: string): Boolean;
    function LoadFromStream(stream: TStream; const FmtExt: string = ''): Boolean;
    function LoadFromResource(const resName: string; resType: PChar): Boolean;

    //properties ...

    property Width: Integer read fWidth;
    property Height: Integer read fHeight;
    //Bounds: Result := Rect(0, 0, Width, Height);
    property Bounds: TRect read GetBounds;
    property IsBlank: Boolean read GetIsBlank;
    property IsEmpty: Boolean read GetIsEmpty;
    property MidPoint: TPointD read GetMidPoint;
    property Pixel[x,y: Integer]: TColor32 read GetPixel write SetPixel;
    property Pixels: TArrayOfColor32 read fPixels;
    property PixelBase: PColor32 read GetPixelBase;
    property PixelRow[row: Integer]: PColor32 read GetPixelRow;
    property ColorCount: Integer read GetColorCount;
    //HasTransparency: Returns true if any pixel's alpha byte < 255.
    property HasTransparency: Boolean read GetHasTransparency;
    //AntiAliased: Antialiasing is used in scaling and rotation transforms
    property AntiAliased: Boolean read fAntiAliase write fAntiAliase;
    property OnChange: TNotifyEvent read fOnChange write fOnChange;
    property OnResize: TNotifyEvent read fOnResize write fOnResize;
  end;

  TImageList32 = class
  private
{$IFDEF XPLAT_GENERICS}
    fList: TList<TImage32>;
{$ELSE}
    fList: TList;
{$ENDIF}
    fIsImageOwner: Boolean;
    function GetImage(index: integer): TImage32;
    procedure SetImage(index: integer; img: TIMage32);
    function GetLast: TImage32;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Count: integer;
    procedure Add(image: TImage32);
    procedure Insert(index: integer; image: TImage32);
    procedure Move(currentIndex, newIndex: integer);
    procedure Delete(index: integer);
    property Image[index: integer]: TImage32 read GetImage write SetImage; default;
    property IsImageOwner: Boolean read fIsImageOwner write fIsImageOwner;
    property Last: TImage32 read GetLast;
  end;

  PARGB = ^TARGB;
  TARGB = packed record
    case boolean of
      false: (B: Byte; G: Byte; R: Byte; A: Byte);
      true : (Color: TColor32);
  end;
  TArrayOfARGB = array of TARGB;
  PArgbArray = ^TArrayOfARGB;

  THsl = packed record
    hue  : byte;
    sat  : byte;
    lum  : byte;
    alpha: byte;
  end;
  PHsl = ^THsl;
  TArrayofHSL = array of THsl;

  PPointD = ^TPointD;
  TPathD = array of TPointD;       //nb: watch for ambiguity with Clipper.pas
  TPathsD = array of TPathD;       //nb: watch for ambiguity with Clipper.pas
  TArrayOfPathsD = array of TPathsD;

  TArrayOfDouble = array of double;
  TArrayOfString = array of string;

  TRectD = {$IFDEF RECORD_METHODS} record {$ELSE} object {$ENDIF}
    Left, Top, Right, Bottom: double;
    function IsEmpty: Boolean;
    function Width: double;
    function Height: double;
    //Normalize: Returns True if swapping either top & bottom or left & right
    function Normalize: Boolean;
    function Contains(const Pt: TPoint): Boolean; overload;
    function Contains(const Pt: TPointD): Boolean; overload;
    function TopLeft: TPointD;
    function BottomRight: TPointD;
    function MidPoint: TPointD;
  end;

  {$IFNDEF PBYTE}
  PByte = type PChar;
  {$ENDIF}

  PWeightedColor = ^TWeightedColor;
  TWeightedColor = {$IFDEF RECORD_METHODS} record {$ELSE} object {$ENDIF}
  private
    fAddCount : Integer;
    fAlphaTot : Int64;
    fColorTotR: Int64;
    fColorTotG: Int64;
    fColorTotB: Int64;
    function GetColor: TColor32;
  public
    procedure Reset;
    procedure Add(c: TColor32; weight: Integer);
    procedure Subtract(c: TColor32; weight: Integer);
    procedure AddWeight(weight: Integer); //ie add clNone32
    property AddCount: Integer read fAddCount;
    property Color: TColor32 read GetColor;
  end;
  TArrayOfWeightedColor = array of TWeightedColor;

  //BLEND FUNCTIONS ( see TImage32.CopyBlend() )

  //BlendToOpaque: Blends a semi-transparent image onto an opaque background
  function BlendToOpaque(bgColor, fgColor: TColor32): TColor32;
  //BlendToAlpha: Blends two semi-transparent images (slower than BlendToOpaque)
  function BlendToAlpha(bgColor, fgColor: TColor32): TColor32;
  //BlendMask: Whereever the mask is, preserves the background
  function BlendMask(bgColor, alphaMask: TColor32): TColor32;
  {$IFDEF INLINE} inline; {$ENDIF}
  function BlendInvertedMask(bgColor, alphaMask: TColor32): TColor32;
  {$IFDEF INLINE} inline; {$ENDIF}

  //COMPARE COLOR FUNCTIONS (ConvertToBoolMask, FloodFill, Vectorize etc.)

  function CompareRGB(master, current: TColor32; tolerance: Integer): Boolean;
  function CompareHue(master, current: TColor32; tolerance: Integer): Boolean;
  function CompareAlpha(master, current: TColor32; tolerance: Integer): Boolean;

  //CompareEx COLOR FUNCTIONS (see ConvertToAlphaMask)
  function CompareRgbEx(master, current: TColor32): Byte;
  function CompareAlphaEx(master, current: TColor32): Byte;

  //MISCELLANEOUS FUNCTIONS ...

  function GetBoolMask(img: TImage32; reference: TColor32;
    compareFunc: TCompareFunction; tolerance: Integer): TArrayOfByte;

  function GetByteMask(img: TImage32; reference: TColor32;
    compareFunc: TCompareFunctionEx): TArrayOfByte;

  //GetWeightedPixel: coordinates x256, y256 are scaled up by 256.
  function GetWeightedPixel(img: TImage32; x256, y256: Integer): TColor32;

  {$IFDEF MSWINDOWS}
  //Color32: Converts a Graphics.TColor value into a TColor32 value.
  function Color32(rgbColor: Integer): TColor32; overload;
  {$ENDIF}
  function Color32(a, r, g, b: Byte): TColor32; overload;

  //RGBColor: Converts a TColor32 value into a COLORREF value
  function RGBColor(color: TColor32): Cardinal;
  function InvertColor(color: TColor32): TColor32;
  procedure Monochrome(var color: TColor32);

  //RgbToHsl: See https://en.wikipedia.org/wiki/HSL_and_HSV
  function RgbToHsl(color: TColor32): THsl;
  //HslToRgb: See https://en.wikipedia.org/wiki/HSL_and_HSV
  function HslToRgb(hslColor: THsl): TColor32;
  function AdjustHue(color: TColor32; percent: Integer): TColor32;
  function ArrayOfColor32ToArrayHSL(const clr32Arr: TArrayOfColor32): TArrayofHSL;
  function ArrayOfHSLToArrayColor32(const hslArr: TArrayofHSL): TArrayOfColor32;

  //Alpha: clears the color channels
  function Alpha(color: TColor32): TColor32;
  //NoAlpha: clears the alpha channel
  function NoAlpha(color: TColor32): TColor32;

  function PointD(const X, Y: Double): TPointD; overload;
  function PointD(const pt: TPoint): TPointD; overload;

  function RectD(left, top, right, bottom: double): TRectD; overload;
  function RectD(const rec: TRect): TRectD; overload;

  function ClampByte(val: Integer): byte;
  function ClampRange(val, min, max: Integer): Integer; overload;
  function ClampRange(val, min, max: single): single; overload;
  function IncPColor32(pc: Pointer; cnt: Integer): PColor32;

  procedure NormalizeAngle(var angle: double);

  {$IFDEF MSWINDOWS}

  //DPIAware: Useful for DPIAware sizing of images and their container controls.
  //It scales values relative to the display's resolution (PixelsPerInch).
  //See https://docs.microsoft.com/en-us/windows/desktop/hidpi/high-DPIAware-desktop-application-development-on-windows
  function DPIAware(val: Integer): Integer; overload; {$IFDEF INLINE} inline; {$ENDIF}
  function DPIAware(val: double): double; overload; {$IFDEF INLINE} inline; {$ENDIF}

  {$IFDEF FPC}
  function AlphaBlend(DC: HDC; p2, p3, p4, p5: Integer;
    DC6: HDC; p7, p8, p9, p10: Integer; p11: Windows.TBlendFunction): BOOL;
    stdcall; external 'msimg32.dll' name 'AlphaBlend';
  {$ENDIF}

  {$ENDIF}

  //CreateResourceStream: handles both numeric and string names and types
  function CreateResourceStream(const resName: string;
    resType: PChar): TResourceStream;

const
  angle180 = Pi;
  angle360 = Pi *2;
  angle0   = 0;
  angle1   = Pi/180;
  angle15  = Pi /12;
  angle30  = angle15 *2;
  angle45  = angle15 *3;
  angle60  = angle15 *4;
  angle75  = angle15 *5;
  angle90  = Pi /2;
  angle105 = angle180 - angle75;
  angle120 = angle180 - angle60;
  angle135 = angle180 - angle45;
  angle150 = angle180 - angle30;
  angle165 = angle180 - angle15;
  angle195 = angle180 + angle15;
  angle210 = angle180 + angle30;
  angle225 = angle180 + angle45;
  angle240 = angle180 + angle60;
  angle255 = angle180 + angle75;
  angle270 = angle360 - angle90;
  angle285 = angle360 - angle75;
  angle300 = angle360 - angle60;
  angle315 = angle360 - angle45;
  angle330 = angle360 - angle30;
  angle345 = angle360 - angle15;

var
  ClockwiseRotationIsAnglePositive: Boolean = true;//false;

  //Both MulTable and DivTable are used in blend functions<br>
  //MulTable[a,b] = a * b / 255
  MulTable: array [Byte,Byte] of Byte;
  //DivTable[a,b] = a * 255/b (for a &lt;= b)
  DivTable: array [Byte,Byte] of Byte;

  //ScreenScale: Useful for DPIAware sizing of images and controls.
  ScreenScale: double = 1.0;

  //AND BECAUSE OLDER DELPHI COMPILERS (OLDER THAN D2006)
  //DON'T SUPPORT RECORD METHODS

  function RectWidth(const rec: TRect): Integer;
  {$IFDEF INLINE} inline; {$ENDIF}
  function RectHeight(const rec: TRect): Integer;
  {$IFDEF INLINE} inline; {$ENDIF}

  function IsEmptyRect(const rec: TRect): Boolean; overload;
  {$IFDEF INLINE} inline; {$ENDIF}
  function IsEmptyRect(const rec: TRectD): Boolean; overload;
  {$IFDEF INLINE} inline; {$ENDIF}

  function SwapRedBlue(color: TColor32): TColor32; overload;
  procedure SwapRedBlue(color: PColor32; count: integer); overload;

  function MulBytes(b1, b2: Byte) : Byte;

implementation

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

const
  div255 : Double = 1 / 255;
type
  TByteArray = array[0..MaxInt -1] of Byte;
  PByteArray = ^TByteArray;

  TImgFmtRec = record
    Fmt: string;
    SortOrder: TClipboardPriority;
    Obj: TImageFormatClass;
  end;
  PImgFmtRec = ^TImgFmtRec;

var
{$IFDEF XPLAT_GENERICS}
  ImageFormatClassList: TList<PImgFmtRec>; //list of supported file extensions
{$ELSE}
  ImageFormatClassList: TList;
{$ENDIF}


//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

procedure NormalizeAngle(var angle: double);
begin
  while angle < 0 do angle := angle + angle360;
  while angle > angle360 do angle := angle - angle360;
  if (angle < 0.01) or (angle > angle360 - 0.01) then angle := 0; // <0.5 deg.
end;
//------------------------------------------------------------------------------

function SwapRedBlue(color: TColor32): TColor32;
var
  c: array[0..3] of byte absolute color;
  r: array[0..3] of byte absolute Result;
begin
  result := color;
  r[0] := c[2];
  r[2] := c[0];
end;
//------------------------------------------------------------------------------

procedure SwapRedBlue(color: PColor32; count: integer);
var
  i: integer;
begin
  for i := 1 to count do
  begin
    color^ := SwapRedBlue(color^);
    inc(color);
  end;
end;
//------------------------------------------------------------------------------

function MulBytes(b1, b2: Byte) : Byte;
  {$IFDEF INLINE} inline; {$ENDIF}
begin
  Result := (b1 * b2) shr 8;
end;
//------------------------------------------------------------------------------

function ImageFormatClassListSort(item1, item2: Pointer): integer;
var
  imgFmtRec1: PImgFmtRec absolute item1;
  imgFmtRec2: PImgFmtRec absolute item2;
begin
  Result := Integer(imgFmtRec1.SortOrder) - Integer(imgFmtRec2.SortOrder);
end;

//------------------------------------------------------------------------------
// Blend functions - used by TImage32.CopyBlend()
//------------------------------------------------------------------------------

function BlendToOpaque(bgColor, fgColor: TColor32): TColor32;
var
  res: TARGB absolute Result;
  bg: TARGB absolute bgColor;
  fg: TARGB absolute fgColor;
  fw,bw: PByteArray;
begin
  if fg.A = 0 then Result := bgColor
  else if fg.A = 255 then Result := fgColor
  else
  begin
    //assuming bg.A = 255, use just fg.A for color weighting
    res.A := 255;
    fw := PByteArray(@MulTable[fg.A]);     //ie weight of foreground
    bw := PByteArray(@MulTable[not fg.A]); //ie weight of foreground
    res.R := fw[fg.R] + bw[bg.R];
    res.G := fw[fg.G] + bw[bg.G];
    res.B := fw[fg.B] + bw[bg.B];
  end;
end;
//------------------------------------------------------------------------------

function BlendToAlpha(bgColor, fgColor: TColor32): TColor32;
var
  res: TARGB absolute Result;
  bg: TARGB absolute bgColor;
  fg: TARGB absolute fgColor;
  fgWeight: byte;
  R, InvR: PByteArray;
begin
  //(see https://en.wikipedia.org/wiki/Alpha_compositing)
  if fg.A = 0 then Result := bgColor
  else if fg.A = 255 then Result := fgColor
  else
  begin
    //combine alphas ...
    //res.A := not MulTable[not fg.A, not bg.A];
    res.A := ((fg.A xor 255) * (bg.A xor 255) shr 8) xor 255; //marginally faster

    fgWeight := DivTable[fg.A, res.A]; //fgWeight = amount foreground color
                                       //contibutes to total (result) color

    R     := PByteArray(@MulTable[fgWeight]);      //ie weight of foreground
    InvR  := PByteArray(@MulTable[not fgWeight]);  //ie weight of foreground
    res.R := R[fg.R] + InvR[bg.R];
    res.G := R[fg.G] + InvR[bg.G];
    res.B := R[fg.B] + InvR[bg.B];
  end;
end;
//------------------------------------------------------------------------------

function BlendMask(bgColor, alphaMask: TColor32): TColor32;
var
  res: TARGB absolute Result;
  bg: TARGB absolute bgColor;
  fg: TARGB absolute alphaMask;
begin
  Result := bgColor;
  res.A := MulBytes(bg.A, fg.A);
  if res.A = 0 then Result := 0;
end;
//------------------------------------------------------------------------------

function BlendInvertedMask(bgColor, alphaMask: TColor32): TColor32;
var
  res: TARGB absolute Result;
  bg: TARGB absolute bgColor;
  fg: TARGB absolute alphaMask;
begin
  Result := bgColor;
  res.A := MulBytes(bg.A, 255 - fg.A);
  if res.A < 2 then Result := 0;
end;

//------------------------------------------------------------------------------
// Compare functions (see ConvertToBoolMask, FloodFill & Vectorize)
//------------------------------------------------------------------------------

function CompareRGB(master, current: TColor32; tolerance: Integer): Boolean;
var
  mast: TARGB absolute master;
  curr: TARGB absolute current;
begin
  if curr.A < $80 then
    Result := false
  else if (master and $FFFFFF) = (current and $FFFFFF) then
    Result := true
  else if tolerance = 0 then
    Result := false
  else result :=
    (Abs(curr.R - mast.R) <= tolerance) and
    (Abs(curr.G - mast.G) <= tolerance) and
    (Abs(curr.B - mast.B) <= tolerance);
end;
//------------------------------------------------------------------------------

function CompareAlpha(master, current: TColor32; tolerance: Integer): Boolean;
var
  mast: TARGB absolute master;
  curr: TARGB absolute current;
begin
  if mast.A = curr.A then Result := true
  else if tolerance = 0 then Result := false
  else result := Abs(curr.A - mast.A) <= tolerance;
end;
//------------------------------------------------------------------------------

function CompareHue(master, current: TColor32; tolerance: Integer): Boolean;
var
  curr, mast: THsl;
  val: Integer;
begin
  if TARGB(current).A < $80 then
  begin
    Result := false;
    Exit;
  end;
  curr := RgbToHsl(current);
  mast := RgbToHsl(master);
  if curr.hue > mast.hue then
  begin
    val := curr.hue - mast.hue;
    if val > 127 then val := mast.hue - curr.hue + 255;
  end else
  begin
    val := mast.hue - curr.hue;
    if val > 127 then val := curr.hue - mast.hue + 255;
  end;
  result := val <= tolerance;
end;

//------------------------------------------------------------------------------
// CompareEx functions (see ConvertToAlphaMask)
//------------------------------------------------------------------------------

function CompareRgbEx(master, current: TColor32): Byte;
var
  mast: TARGB absolute master;
  curr: TARGB absolute current;
  res: Cardinal;
begin
  if curr.A = 0 then
  begin
    Result := 0;
  end else
  begin
    res := Sqr(mast.R - curr.R) + Sqr(mast.G - curr.G) + Sqr(mast.B - curr.B);
    if res >= 65025 then result := 0
    else result := 255 - Round(Sqrt(res));
    if curr.A < 255 then result := MulBytes(result, curr.A);
  end;
end;
//------------------------------------------------------------------------------

function CompareAlphaEx(master, current: TColor32): Byte;
var
  mast: TARGB absolute master;
  curr: TARGB absolute current;
begin
  Result := 255 - abs(mast.A - curr.A);
end;

//------------------------------------------------------------------------------
// Miscellaneous functions ...
//------------------------------------------------------------------------------

function IsAlphaChar(c: Char): Boolean;
begin
  Result := ((c >= 'A') and (c <= 'Z')) or ((c >= 'a') and (c <= 'z'));
end;
//------------------------------------------------------------------------------

function RectWidth(const rec: TRect): Integer;
begin
  Result := rec.Right - rec.Left;
end;
//------------------------------------------------------------------------------

function RectHeight(const rec: TRect): Integer;
begin
  Result := rec.Bottom - rec.Top;
end;
//------------------------------------------------------------------------------

function IsEmptyRect(const rec: TRect): Boolean;
begin
  Result := (rec.Right <= rec.Left) or (rec.Bottom <= rec.Top);
end;
//------------------------------------------------------------------------------

function IsEmptyRect(const rec: TRectD): Boolean;
begin
  Result := (rec.Right <= rec.Left) or (rec.Bottom <= rec.Top);
end;
//------------------------------------------------------------------------------

function InvertColor(color: TColor32): TColor32;
var
  c: TARGB absolute color;
  r: TARGB absolute Result;
begin
  r.A := c.A;
  r.R := 255 - c.R;
  r.G := 255 - c.G;
  r.B := 255 - c.B;
end;
//------------------------------------------------------------------------------

procedure Monochrome(var color: TColor32);
var
  c: TARGB absolute color;
begin
  c.R := (c.R * 61 + c.G * 174 + c.B * 21) shr 8;
  if c.R > 127 then c.R := 255 else c.R := 0;
  c.G := c.R; c.B := c.R; c.A := 255;
end;
//------------------------------------------------------------------------------

function Alpha(color: TColor32): TColor32;
{$IFDEF INLINE} inline; {$ENDIF}
begin
  Result := (color and $FF000000);
end;
//------------------------------------------------------------------------------

function NoAlpha(color: TColor32): TColor32;
{$IFDEF INLINE} inline; {$ENDIF}
begin
  Result := (color and $FFFFFF);
end;
//------------------------------------------------------------------------------

function RGBColor(color: TColor32): Cardinal;
var
  c  : TARGB absolute color;
  res: TARGB absolute Result;
begin
  res.R := c.B; res.G := c.G; res.B := c.R; res.A := 0;
end;
//------------------------------------------------------------------------------

function Color32(a, r, g, b: Byte): TColor32;
var
  res: TARGB absolute Result;
begin
  res.A := a; res.R := r; res.G := g; res.B := b;
end;
//------------------------------------------------------------------------------

{$IFDEF MSWINDOWS}
function Color32(rgbColor: Integer): TColor32;
var
  res: TARGB absolute Result;
begin
  if rgbColor < 0 then
    result := GetSysColor(rgbColor and $FFFFFF) else
    result := rgbColor;
  res.A := res.B; res.B := res.R; res.R := res.A; //byte swap
  res.A := 255;
end;
//------------------------------------------------------------------------------

function Get32bitBitmapInfoHeader(width, height: Integer): TBitmapInfoHeader;
begin
  FillChar(Result, sizeof(Result), #0);
  Result.biSize := sizeof(TBitmapInfoHeader);
  Result.biWidth := width;
  Result.biHeight := height;
  Result.biPlanes := 1;
  Result.biBitCount := 32;
  Result.biSizeImage := width * height * SizeOf(TColor32);
  Result.biCompression := BI_RGB;
end;
//------------------------------------------------------------------------------

function DPIAware(val: Integer): Integer;
begin
  result := Round( val * ScreenScale);
end;
//------------------------------------------------------------------------------

function DPIAware(val: double): double;
begin
  result := val * ScreenScale;
end;
//------------------------------------------------------------------------------
{$ENDIF}

function RectsEqual(const rec1, rec2: TRect): Boolean;
begin
  result := (rec1.Left = rec2.Left) and (rec1.Top = rec2.Top) and
    (rec1.Right = rec2.Right) and (rec1.Bottom = rec2.Bottom);
end;
//------------------------------------------------------------------------------

function ClampByte(val: Integer): byte;
begin
  if val < 0 then result := 0
  else if val > 255 then result := 255
  else result := val;
end;
//------------------------------------------------------------------------------

function ClampRange(val, min, max: Integer): Integer;
begin
  if val < min then result := min
  else if val > max then result := max
  else result := val;
end;
//------------------------------------------------------------------------------

function ClampRange(val, min, max: single): single;
begin
  if val < min then result := min
  else if val > max then result := max
  else result := val;
end;
//------------------------------------------------------------------------------

procedure ScaleRect(var rec: TRect; scale: TPointD);
begin
  rec.Right := rec.Left + Round((rec.Right - rec.Left) * scale.X);
  rec.Bottom := rec.Top + Round((rec.Bottom - rec.Top) * scale.Y);
end;
//------------------------------------------------------------------------------

function IncPColor32(pc: Pointer; cnt: Integer): PColor32;
begin
  result := PColor32(PByte(pc) + cnt * SizeOf(TColor32));
end;
//------------------------------------------------------------------------------

function DivRound(num, denom: Integer): Byte;

begin
  result := ClampByte((num  + (denom div 2)) div denom);
end;
//------------------------------------------------------------------------------

function PointD(const X, Y: Double): TPointD;
begin
  Result.X := X;
  Result.Y := Y;
end;
//------------------------------------------------------------------------------

function PointD(const pt: TPoint): TPointD;
begin
  Result.X := pt.X;
  Result.Y := pt.Y;
end;
//------------------------------------------------------------------------------

procedure RotatePt(var pt: TPointD; const origin: TPointD; sinA, cosA: double);
var
  tmpX, tmpY: double;
begin
  tmpX := pt.X-origin.X;
  tmpY := pt.Y-origin.Y;
  pt.X := tmpX * cosA - tmpY * sinA + origin.X;
  pt.Y := tmpX * sinA + tmpY * cosA + origin.Y;
end;
//------------------------------------------------------------------------------

function GetRotatedRectBounds(const rec: TRectD; angle: double): TRectD;
var
  s,c: extended;
  w,h: double;
begin
  //nb: direction doesn't matter re. ClockwiseRotationIsAnglePositive

  NormalizeAngle(angle);
  if angle <> 0 then
  begin
    SinCos(angle, s, c);
    s := Abs(s); c := Abs(c);
    w := (rec.Width *c + rec.Height *s) /2;
    h := (rec.Width *s + rec.Height *c) /2;
    with rec.MidPoint do
      Result := RectD(X - w, Y - h, X + w, Y +h);
  end
  else
    Result := rec;
end;
//------------------------------------------------------------------------------

function GetBoolMask(img: TImage32; reference: TColor32;
  compareFunc: TCompareFunction; tolerance: Integer): TArrayOfByte;
var
  i: integer;
  pa: PByte;
  pc: PColor32;
begin
  result := nil;
  if not assigned(img) or img.IsEmpty then Exit;
  if not Assigned(compareFunc) then compareFunc := CompareRGB;
  SetLength(Result, img.Width * img.Height);
  pa := @Result[0];
  pc := img.PixelBase;
  for i := 0 to img.Width * img.Height -1 do
  begin
    if compareFunc(reference, pc^, tolerance) then
  {$IFDEF PBYTE}
      pa^ := 1 else
      pa^ := 0;
  {$ELSE}
      pa^ := #1 else
      pa^ := #0;
  {$ENDIF}
    inc(pc); inc(pa);
  end;
end;
//------------------------------------------------------------------------------

function GetAlpha(master, current: TColor32): Byte;
{$IFDEF INLINE} inline; {$ENDIF}
var
  curr: TARGB absolute current;
begin
  result := curr.A; //nb: 'master' is ignored
end;
//------------------------------------------------------------------------------

function GetByteMask(img: TImage32; reference: TColor32;
  compareFunc: TCompareFunctionEx): TArrayOfByte;
var
  i: integer;
  pa: PByte;
  pc: PColor32;
begin
  result := nil;
  if not assigned(img) or img.IsEmpty then Exit;
  if not Assigned(compareFunc) then compareFunc := GetAlpha;
  SetLength(Result, img.Width * img.Height);
  pa := @Result[0];
  pc := img.PixelBase;
  for i := 0 to img.Width * img.Height -1 do
  begin
    {$IFDEF PBYTE}
    pa^ := compareFunc(reference, pc^);
    {$ELSE}
    pa^ := Char(compareFunc(reference, pc^));
    {$ENDIF}
    inc(pc); inc(pa);
  end;
end;
//------------------------------------------------------------------------------

function GetWeightedPixel(img: TImage32; x256, y256: Integer): TColor32;
var
  xi, yi, weight: Integer;
  width, height: integer;
  pixels: TArrayOfColor32;
  color: TWeightedColor;
  xf, yf: cardinal;
begin
  width := img.Width; height := img.Height;
  pixels := img.Pixels;
  //coordinate integers (can be negative) -> x256 div 256 & y256 div 256.
  //coordinate fractions ->  (x256 and $FF) / 256 & (y256 and $FF) / 256
  if (x256 < -$FF) or (y256 < -$FF) or
    (x256 >= width * $100) or (y256 >= height * $100) then
  begin
    result := clNone32;
    Exit;
  end;
  xi := abs(x256) shr 8;
  xf := x256 and $FF;
  yi := abs(y256) shr 8;
  yf := y256 and $FF;

  color.Reset;
  weight := (($100 - xf) * ($100 - yf)) shr 8;         //top-left
  if (x256 < 0) or (y256 < 0) then
    color.AddWeight(weight) else
    color.Add(pixels[xi + yi * width], weight);

  weight := (xf * ($100 - yf)) shr 8;                  //top-right
  if (xi + 1 >= width) or (y256 < 0) then
    color.AddWeight(weight) else
    color.Add(pixels[xi + 1 + yi * width], weight);

  weight := (($100 - xf) * yf) shr 8;                  //bottom-left
  if (x256 < 0) or (yi + 1 = height) then
    color.AddWeight(weight) else
    color.Add(pixels[xi + (yi +1) * width], weight);

  weight := (xf * yf) shr 8;                           //bottom-right
  if (xi + 1 >= width) or (yi + 1 = height) then
    color.AddWeight(weight) else
    color.Add(pixels[(xi + 1)  + (yi + 1) * width], weight);
  Result := color.Color;
end;
//------------------------------------------------------------------------------

function GetWeightedColor(const srcBits: TArrayOfColor32;
  x256, y256, xx256, yy256, maxX: Integer): TColor32;
var
  i, j, xi, yi, xxi, yyi, weight: Integer;
  xf, yf, xxf, yyf: cardinal;
  color: TWeightedColor;
begin
  //note: This function differs from GetWeightedPixel in one very important
  //aspect - this function accommodates weighting any number of pixels
  //(rather than just adjacent pixels) which is important went performing
  //significant downsizing.

  color.Reset;

  xi := x256 shr 8; xf := x256 and $FF;
  yi := y256 shr 8; yf := y256 and $FF;
  xxi := xx256 shr 8; xxf := xx256 and $FF;
  yyi := yy256 shr 8; yyf := yy256 and $FF;

  //1. average the corners ...
  weight := (($100 - xf) * ($100 - yf)) shr 8;
  color.Add(srcBits[xi + yi * maxX], weight);
  weight := (xxf * ($100 - yf)) shr 8;
  if (weight <> 0) then color.Add(srcBits[xxi + yi * maxX], weight);
  weight := (($100 - xf) * yyf) shr 8;
  if (weight <> 0) then color.Add(srcBits[xi + yyi * maxX], weight);
  weight := (xxf * yyf) shr 8;
  if (weight <> 0) then color.Add(srcBits[xxi + yyi * maxX], weight);

  //2. average the edges
  if (yi +1 < yyi) then
  begin
    xf := $100 - xf;
    for i := yi + 1 to yyi - 1 do
      color.Add(srcBits[xi + i * maxX], xf);
    if (xxf <> 0) then
      for i := yi + 1 to yyi - 1 do
        color.Add(srcBits[xxi + i * maxX], xxf);
  end;
  if (xi + 1 < xxi) then
  begin
    yf := $100 - yf;
    for i := xi + 1 to xxi - 1 do
      color.Add(srcBits[i + yi * maxX], yf);
    if (yyf <> 0) then
      for i := xi + 1 to xxi - 1 do
        color.Add(srcBits[i + yyi * maxX], yyf);
  end;

  //3. average the non-fractional pixel 'internals' ...
  for i := xi + 1 to xxi - 1 do
    for j := yi + 1 to yyi - 1 do
      color.Add(srcBits[i + j * maxX], $100);

  //4. finally get the weighted color ...
  if color.AddCount = 0 then
    Result := srcBits[xi + yi * maxX] else
    Result := color.Color;
end;
//------------------------------------------------------------------------------

function RgbToHsl(color: TColor32): THsl;
var
  rgba: TARGB absolute color;
  hsl: THsl absolute result;
  r,g,b: byte;
  maxRGB, minRGB, mAdd, mSub: Integer;
begin
  //https://en.wikipedia.org/wiki/HSL_and_HSV and
  //http://en.wikipedia.org/wiki/HSL_color_space
{$IFDEF ANDROID}
  color := SwapRedBlue(color);
{$ENDIF}

  r := rgba.R; g := rgba.G; b := rgba.B;
  maxRGB := Max(r, Max(g, b));
  minRGB := Min(r, Min(g, b));
  mAdd := maxRGB + minRGB;
  hsl.lum := mAdd shr 1;
  hsl.alpha := rgba.A;

  if maxRGB = minRGB then
  begin
    hsl.hue := 0; //hsl.hue is undefined when gray
    hsl.sat := 0;
    Exit;
  end;

  mSub := maxRGB - minRGB;
  if mAdd <= 255 then
    hsl.sat := DivTable[mSub, mAdd] else
    hsl.sat := DivTable[mSub, 511 - mAdd];

  mSub := mSub * 6;
  if r = maxRGB then
  begin
    if g >= b then
      hsl.hue := (g - b) * 255 div mSub else
      hsl.hue := 255 - ((b - g) * 255 div mSub);
  end
  else if G = maxRGB then
  begin
    if b > r then
      hsl.hue := 85 + (b - r) * 255 div mSub else
      hsl.hue := 85 - (r - b)  * 255 div mSub;
  end else
  begin
    if r > g then
      hsl.hue := 170 + (r - g)  * 255 div mSub else
      hsl.hue := 170 - (g - r)  * 255 div mSub;
  end;
end;
//------------------------------------------------------------------------------

function HslToRgb(hslColor: THsl): TColor32;
var
  rgba: TARGB absolute result;
  hsl: THsl absolute hslColor;
  c, x, m: Integer;
begin
  //formula from https://www.rapidtables.com/convert/color/hsl-to-rgb.html
  c := (255 - abs(2 * hsl.lum - 255)) * hsl.sat div 255;
  x := c * (255 - abs((hsl.hue mod 85) * 6 - 255)) div 255;
  m := hsl.lum - c div 2;
  rgba.A := hsl.alpha;
  case (hsl.hue * 6) shr 8 of
    0: begin rgba.R := c + m; rgba.G := x + m; rgba.B := 0 + m; end;
    1: begin rgba.R := x + m; rgba.G := c + m; rgba.B := 0 + m; end;
    2: begin rgba.R := 0 + m; rgba.G := c + m; rgba.B := x + m; end;
    3: begin rgba.R := 0 + m; rgba.G := x + m; rgba.B := c + m; end;
    4: begin rgba.R := x + m; rgba.G := 0 + m; rgba.B := c + m; end;
    5: begin rgba.R := c + m; rgba.G := 0 + m; rgba.B := x + m; end;
  end;
{$IFDEF ANDROID}
  Result := SwapRedBlue(Result);
{$ENDIF}
end;
//------------------------------------------------------------------------------

function AdjustHue(color: TColor32; percent: Integer): TColor32;
var
  hsl: THsl;
begin
  percent := percent mod 100;
  if percent < 0 then inc(percent, 100);
  hsl := RgbToHsl(color);
  hsl.hue := (hsl.hue + Round(percent*255/100)) mod 256;
  result := HslToRgb(hsl);
end;
//------------------------------------------------------------------------------

function ArrayOfColor32ToArrayHSL(const clr32Arr: TArrayOfColor32): TArrayofHSL;
var
  i, len: Integer;
begin
  len := length(clr32Arr);
  setLength(result, len);
  for i := 0 to len -1 do
    result[i] := RgbToHsl(clr32Arr[i]);
end;
//------------------------------------------------------------------------------

function ArrayOfHSLToArrayColor32(const hslArr: TArrayofHSL): TArrayOfColor32;
var
  i, len: Integer;
begin
  len := length(hslArr);
  setLength(result, len);
  for i := 0 to len -1 do
    result[i] := HslToRgb(hslArr[i]);
end;
//------------------------------------------------------------------------------

function NameToId(Name: PChar): Longint;
begin
  if Cardinal(PWord(Name)) < 30 then
  begin
    Result := Cardinal(PWord(Name))
  end else
  begin
    if Name^ = '#' then inc(Name);
    Result := StrToIntDef(Name, 0);
    if Result > 65535 then Result := 0;
  end;
end;
//------------------------------------------------------------------------------

function CreateResourceStream(const resName: string;
  resType: PChar): TResourceStream;
var
  nameId, typeId: Cardinal;
begin
  Result := nil;
  typeId := NameToId(resType);
  if (typeId > 0) then resType := PChar(typeId)
  else if (resType = 'BMP') then resType := RT_BITMAP;

  nameId := NameToId(PChar(resName));
  if nameId > 0 then
  begin
    if FindResource(hInstance, PChar(nameId), resType) <> 0 then
      Result := TResourceStream.CreateFromID(hInstance, nameId, resType);
  end else
  begin
    if FindResource(hInstance, PChar(resName), resType) <> 0 then
      Result := TResourceStream.Create(hInstance, PChar(resName), resType);
  end;
end;

//------------------------------------------------------------------------------
// TRectD methods (and helpers)
//------------------------------------------------------------------------------

function TRectD.IsEmpty: Boolean;
begin
  result := (right <= left) or (bottom <= top);
end;
//------------------------------------------------------------------------------

function TRectD.Width: double;
begin
  result := Max(0, right - left);
end;
//------------------------------------------------------------------------------

function TRectD.Height: double;
begin
  result := Max(0, bottom - top);
end;
//------------------------------------------------------------------------------

function TRectD.TopLeft: TPointD;
begin
  result := PointD(Left, Top);
end;
//------------------------------------------------------------------------------

function TRectD.BottomRight: TPointD;
begin
  result := PointD(Right, Bottom);
end;
//------------------------------------------------------------------------------

function TRectD.MidPoint: TPointD;
begin
  Result.X := (Right + Left)/2;
  Result.Y := (Bottom + Top)/2;
end;
//------------------------------------------------------------------------------

function TRectD.Normalize: Boolean;
var
  d: double;
begin
  Result := false;
  if Left > Right then
  begin
    d := Left;
    Left := Right;
    Right := d;
    Result := True;
  end;
  if Top > Bottom then
  begin
    d := Top;
    Top := Bottom;
    Bottom := d;
    Result := True;
  end;
end;
//------------------------------------------------------------------------------

function TRectD.Contains(const Pt: TPoint): Boolean;
begin
  Result := (pt.X >= Left) and (pt.X < Right) and
    (pt.Y >= Top) and (pt.Y < Bottom);
end;
//------------------------------------------------------------------------------

function TRectD.Contains(const Pt: TPointD): Boolean;
begin
  Result := (pt.X >= Left) and (pt.X < Right) and
    (pt.Y >= Top) and (pt.Y < Bottom);
end;
//------------------------------------------------------------------------------

function RectD(left, top, right, bottom: double): TRectD;
begin
  result.Left := left;
  result.Top := top;
  result.Right := right;
  result.Bottom := bottom;
end;
//------------------------------------------------------------------------------

function RectD(const rec: TRect): TRectD;
begin
  with rec do
  begin
    result.Left := left;
    result.Top := top;
    result.Right := right;
    result.Bottom := bottom;
  end;
end;

//------------------------------------------------------------------------------
// TImage32 methods
//------------------------------------------------------------------------------

constructor TImage32.Create(width: Integer; height: Integer);
begin
  fAntiAliase := true;
  fwidth := Max(0, width);
  fheight := Max(0, height);
  SetLength(fPixels, fwidth * fheight);
end;
//------------------------------------------------------------------------------

constructor TImage32.Create(src: TImage32);
begin
  Assign(src);
end;
//------------------------------------------------------------------------------

constructor TImage32.Create(src: TImage32; const srcRec: TRect);
begin
  fAntiAliase := src.fAntiAliase;
  fUpdateCnt := 1;
  SetSize(RectWidth(srcRec), RectHeight(srcRec));
  if not IsEmptyRect(srcRec) then
    fPixels := src.CopyPixels(srcRec);
  fUpdateCnt := 0;
end;
//------------------------------------------------------------------------------

destructor TImage32.Destroy;
begin
  fPixels := nil;
  inherited;
end;
//------------------------------------------------------------------------------

class function TImage32.IsRegisteredFormat(const ext: string): Boolean;
begin
  result := Assigned(TImage32.GetImageFormatClass(ext));
end;
//------------------------------------------------------------------------------

class procedure TImage32.RegisterImageFormatClass(ext: string;
  bm32ExClass: TImageFormatClass; clipPriority: TClipboardPriority);
var
  i: Integer;
  imgFmtRec: PImgFmtRec;
begin
  if (ext = '') or (ext = '.') then Exit;
  if (ext[1] = '.') then Delete(ext, 1,1);
  if not IsAlphaChar(ext[1]) then Exit;
  //avoid duplicates
  for i := 0 to imageFormatClassList.count -1 do
  begin
    imgFmtRec := PImgFmtRec(imageFormatClassList[i]);
    if SameText(imgFmtRec.Fmt, ext) then Exit;
  end;

  //ImageFormatClassList is sorted with lowest priority first in list
  new(imgFmtRec);
  imgFmtRec.Fmt := ext;
  imgFmtRec.SortOrder := clipPriority;
  imgFmtRec.Obj := bm32ExClass;
  ImageFormatClassList.Add(imgFmtRec);
  //sorting here is arguably inefficient, but there will be so few
  //entries in the list that this inefficiency will be inconsequential.

{$IFDEF XPLAT_GENERICS}
  ImageFormatClassList.Sort(TComparer<PImgFmtRec>.Construct(
      function(const imgFmtRec1, imgFmtRec2: PImgFmtRec): Integer
      begin
        Result := Integer(imgFmtRec1.SortOrder) - Integer(imgFmtRec2.SortOrder);
      end));
{$ELSE}
  ImageFormatClassList.Sort(ImageFormatClassListSort);
{$ENDIF}
end;
//------------------------------------------------------------------------------

class function TImage32.GetImageFormatClass(const ext: string): TImageFormatClass;
var
  i: Integer;
  pattern: string;
  imgFmtRec: PImgFmtRec;
begin
  Result := nil;
  pattern := ext;
  if (pattern = '')  or (pattern = '.') then Exit;
  if pattern[1] = '.' then Delete(pattern, 1,1);

  //try for highest priority first
  for i := imageFormatClassList.count -1 downto 0 do
  begin
    imgFmtRec := PImgFmtRec(imageFormatClassList[i]);
    if not SameText(imgFmtRec.Fmt, pattern) then Continue;
    Result := imgFmtRec.Obj;
    break;
  end;
end;
//------------------------------------------------------------------------------

class function TImage32.GetExtFromImageStream(stream: TStream): string;
var
  i, pos, len: Integer;
  flag: Cardinal;
  buffer: array [0..79] of Byte;
const
  SizeOfBitmapInfoHeader = 40;
  SizeOfBitmapV4Header = 108;
  SizeOfBitmapV5Header = 124;
begin
  result := '';
  pos := stream.position;
  len := stream.size - pos;
  if len <= 4 then Exit;
  stream.read(flag, SizeOf(flag));
  if ((flag and $FFFF) = $4D42) then Result := 'BMP'
  else if (flag = SizeOfBitmapInfoHeader) then Result := 'BMP' //resource_2
  else if (flag = SizeOfBitmapV4Header) then Result := 'BMP'   //resource_2
  else if (flag = SizeOfBitmapV5Header) then Result := 'BMP'   //resource_2
  else if flag = $38464947 then result := 'GIF'
  else if flag and $FFFF = $D8FF then result := 'JPG'
  else if flag = $474E5089 then result := 'PNG'
  else if (flag = $002A4949) or (flag = $2A004949) then result := 'TIF'
  else
  begin
    len := min(len, 80);
    stream.read(buffer[0], len);
    for i := 0 to len -1 do if (buffer[i] < 9) then Exit;
    Result := 'TXT'; //possibly MIME encoded
  end;
  stream.position := pos;
end;
//------------------------------------------------------------------------------

procedure TImage32.Assign(src: TImage32);
begin
  if assigned(src) then
    src.AssignTo(self);
end;
//------------------------------------------------------------------------------

procedure TImage32.AssignTo(dst: TImage32);
begin
  if dst = self then Exit;
  dst.BeginUpdate;
  try
    dst.fAntiAliase := fAntiAliase;
    dst.fIsPremultiplied := fIsPremultiplied;
    dst.fColorCount := 0;
    try
      dst.SetSize(Width, Height);
      if (Width > 0) and (Height > 0) then
        move(fPixels[0], dst.fPixels[0], Width * Height * SizeOf(TColor32));
    except
      dst.SetSize(0,0);
    end;
  finally
    dst.EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure TImage32.Changed;
begin
  if fUpdateCnt <> 0 then Exit;
  fColorCount := 0;
  if Assigned(fOnChange) then fOnChange(Self);
end;
//------------------------------------------------------------------------------

procedure TImage32.Resized;
begin
  if Assigned(fOnResize) then fOnResize(Self);
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.BeginUpdate;
begin
  inc(fUpdateCnt);
end;
//------------------------------------------------------------------------------

procedure TImage32.EndUpdate;
begin
  dec(fUpdateCnt);
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.SetBackgroundColor(bgColor: TColor32);
var
  i: Integer;
  pc: PColor32;
begin
  pc := Pixelbase;
  for i := 0 to high(fPixels) do
  begin
    pc^ := BlendToOpaque(bgColor, pc^);
     inc(pc);
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.Clear(color: TColor32);
var
  i: Integer;
  pc: PColor32;
begin
  fIsPremultiplied := false;
  if IsEmpty then Exit;
  if color = clNone32 then
    FillChar(fPixels[0], Width * Height * SizeOf(TColor32), 0)
  else
  begin
    pc := PixelBase;
    for i := 0 to Width * Height -1 do
    begin
      pc^ := color;
      inc(pc);
    end;
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.FillRect(rec: TRect; color: TColor32);
var
  i,j, rw: Integer;
  c: PColor32;
begin
  IntersectRect(rec, rec, bounds);
  if IsEmptyRect(rec) then Exit;
  rw := RectWidth(rec);
  c := @Pixels[rec.Top * Width + rec.Left];
  for i := rec.Top to rec.Bottom -1 do
  begin
    for j := 1 to rw do
    begin
      c^ := color;
      inc(c);
    end;
    inc(c, Width - rw);
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure CheckBlendFill(pc: PColor32; color: TColor32);
{$IFDEF INLINE} inline; {$ENDIF}
begin
  if not assigned(pc) then Exit;
  pc^ := BlendToAlpha(pc^, color);
end;
//------------------------------------------------------------------------------

function TImage32.CopyPixels(rec: TRect): TArrayOfColor32;
var
  i, clipW, w,h: Integer;
  pSrc, pDst, pDst2: PColor32;
  recClipped: TRect;
begin
  w := RectWidth(rec);
  h := RectHeight(rec);
  setLength(result, w * h);

  if w * h = 0 then Exit;
  IntersectRect(recClipped, rec, Bounds);
  //if recClipped is wholely outside the bounds of the image ...
  if IsEmptyRect(recClipped) then
  begin
    //rec is considered valid even when completely outside the image bounds,
    //and so when that happens we simply return a fully transparent image ...
    FillChar(Result[0], w * h * SizeOf(TColor32), 0);
    Changed;
    Exit;
  end;

  //if recClipped is wholely within the bounds of the image ...
  if RectsEqual(recClipped, rec) then
  begin
    pDst := @Result[0];
    pSrc := @fPixels[recClipped.Top * Width + rec.Left];
    for i := recClipped.Top to recClipped.Bottom -1 do
    begin
      Move(pSrc^, pDst^, w * SizeOf(TColor32));
      inc(pSrc, Width); inc(pDst, w);
    end;
    Changed;
    Exit;
  end;

  //a part of 'rec' must be outside the bounds of the image ...

  pDst := @Result[0];
  for i := rec.Top to -1 do
  begin
    FillChar(pDst^, w * SizeOf(TColor32), 0);
    inc(pDst, w);
  end;
  pSrc := @fPixels[recClipped.Top * Width + Max(0,rec.Left)];
  if (rec.Left < 0) or (rec.Right > Width) then
  begin
    clipW := RectWidth(recClipped);
    pDst2 := IncPColor32(pDst, -Min(0, rec.Left));
    for i := recClipped.Top to recClipped.Bottom -1 do
    begin
      //when rec.left < 0 or rec.right > width it's simplest to
      //start with a prefilled row of transparent pixels
      FillChar(pDst^, w * SizeOf(TColor32), 0);
      Move(pSrc^, pDst2^, clipW * SizeOf(TColor32));
      inc(pDst, w); inc(pDst2, w); inc(pSrc, Width);
    end;
  end else
  begin
    //things are simpler when there's no part of 'rec' is
    //outside the image, at least not on the left or right sides ...
    for i := recClipped.Top to recClipped.Bottom -1 do
    begin
      Move(pSrc^, pDst^, w * SizeOf(TColor32));
      inc(pSrc, Width); inc(pDst, w);
    end;
  end;
  for i := Height to rec.Bottom -1 do
  begin
    FillChar(pDst^, w * SizeOf(TColor32), 0);
    inc(pDst, w);
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.Crop(const rec: TRect);
var
  newPixels: TArrayOfColor32;
begin
  newPixels := CopyPixels(rec);
  BeginUpdate;
  try
    SetSize(RectWidth(rec), RectHeight(rec));
    if not IsEmptyRect(rec) then fPixels := newPixels;
  finally
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

function TImage32.GetBounds: TRect;
begin
  result := Types.Rect(0, 0, Width, Height);
end;
//------------------------------------------------------------------------------

function TImage32.GetMidPoint: TPointD;
begin
  Result := PointD(fWidth * 0.5, fHeight * 0.5);
end;
//------------------------------------------------------------------------------

procedure TImage32.SetSize(newWidth, newHeight: Integer; color: TColor32);
begin
  fwidth := Max(0, newWidth);
  fheight := Max(0, newHeight);
  fPixels := nil; //prevents unnecessary (and unsafe) pixel copy
  SetLength(fPixels, fwidth * fheight);
  fIsPremultiplied := false;
  BeginUpdate;
  try
    if color > 0 then Clear(color);
    Resized;
  finally
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure TImage32.Resize(newWidth, newHeight: Integer; stretchImage: Boolean);
var
  tmp: TImage32;
  rec: TRect;
begin
  if (newWidth <= 0) or (newHeight <= 0) then
  begin
    SetSize(0, 0);
    Exit;

  end;
  if (newWidth = fwidth) and (newHeight = fheight) then Exit;

  if IsEmpty then
  begin
    SetSize(newWidth, newHeight);
    Exit;
  end;

  BeginUpdate;
  try
    if stretchImage then
    begin
      if fAntiAliase then
        InternalStretchResizeAA(newWidth, newHeight) else
        InternalStretchResizeFast(newWidth, newHeight);
    end else
    begin
      tmp := TImage32.create(self);
      try
        rec := Bounds;
        SetSize(newWidth, newHeight, clNone32);
        CopyBlend(tmp, rec, rec);
      finally
        tmp.Free;
      end;
    end;
  finally
    Resized;
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure TImage32.InternalStretchResizeFast(newWidth, newHeight: Integer);
var
  x, y, srcY: Integer;
  scaledXi, scaledYi: TArrayOfInteger;
  tmp: TArrayOfColor32;
  pc: PColor32;
begin
  if (newWidth = fWidth) and (newHeight = fHeight) then Exit;
  SetLength(tmp, newWidth * newHeight * SizeOf(TColor32));

  //get scaled X & Y values once only (storing them in lookup arrays) ...
  SetLength(scaledXi, newWidth);
  for x := 0 to newWidth -1 do
    scaledXi[x] := Floor(x * fWidth / newWidth);
  SetLength(scaledYi, newHeight);
  for y := 0 to newHeight -1 do
    scaledYi[y] := Floor(y * fHeight / newHeight);

  pc := @tmp[0];
  for y := 0 to newHeight - 1 do
  begin
    srcY := scaledYi[y];
    if (srcY < 0) or (srcY >= fHeight) then Continue;
    for x := 0 to newWidth - 1 do
    begin
      pc^ := fPixels[scaledXi[x] + srcY * fWidth];
      inc(pc);
    end;
  end;

  fPixels := tmp;
  fwidth := newWidth;
  fheight := newHeight;
end;
//------------------------------------------------------------------------------

procedure TImage32.InternalStretchResizeAA(newWidth, newHeight: Integer);
var
  x,y, x256,y256,xx256,yy256: Integer;
  sx,sy: double;
  tmp: TArrayOfColor32;
  pc: PColor32;
  scaledX: array of Integer;
begin
  sx := fWidth/newWidth * 256;
  sy := fHeight/newHeight * 256;
  SetLength(tmp, newWidth * newHeight);

  SetLength(scaledX, newWidth +1); //+1 for fractional overrun
  for x := 0 to newWidth -1 do
    scaledX[x] := Round((x+1) * sx);

  y256 := 0;
  pc := @tmp[0];
  for y := 0 to newHeight - 1 do
  begin
    x256 := 0;
    yy256 := Round((y+1) * sy);
    for x := 0 to newWidth - 1 do
    begin
      xx256 := scaledX[x];
      pc^ := GetWeightedColor(fPixels, x256, y256, xx256, yy256, fWidth);
      x256 := xx256;
      inc(pc);
    end;
    y256 := yy256;
  end;

  fPixels := tmp;
  fwidth := newWidth;
  fheight := newHeight;
end;
//------------------------------------------------------------------------------

procedure TImage32.Scale(s: single);
begin
  Scale(s, s);
end;
//------------------------------------------------------------------------------

procedure TImage32.Scale(sx, sy: single);
begin
  sx := Min(sx, 100); sy := Min(sy, 100);
  if (sx > 0) and (sy > 0) then
    ReSize(Round(width * sx), Round(height * sy));
end;
//------------------------------------------------------------------------------

procedure TImage32.ScaleToFit(width, height: integer);
var
  sx, sy: double;
begin
  if IsEmpty or (width <= 0) or (height <= 0) then Exit;
  sx := width / self.Width;
  sy := height / self.Height;
  if sx <= sy then
    Scale(sx) else
    Scale(sy);
end;
//------------------------------------------------------------------------------

procedure TImage32.ScaleToFitCentered(width, height: integer);
var
  sx, sy: double;
  tmp: TImage32;
  rec2: TRect;
begin
  if IsEmpty or (width <= 0) or (height <= 0) then Exit;
  sx := width / self.Width;
  sy := height / self.Height;
  BeginUpdate;
  try
    if sx <= sy then
    begin
      Scale(sx);
      if height = self.Height then Exit;
      rec2 := Bounds;
      Types.OffsetRect(rec2, 0, (height - self.Height) div 2);
      tmp := TImage32.Create(self);
      try
        SetSize(width, height);
        CopyInternal(tmp, tmp.Bounds, rec2, nil);
      finally
        tmp.Free;
      end;
    end else
    begin
      Scale(sy);
      if width = self.Width then Exit;
      rec2 := Bounds;
      Types.OffsetRect(rec2, (width - self.Width) div 2, 0);
      tmp := TImage32.Create(self);
      try
        SetSize(width, height);
        CopyInternal(tmp, tmp.Bounds, rec2, nil);
      finally
        tmp.Free;
      end;
    end;
  finally
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure TImage32.RotateLeft90;
var
  x,y, xx: Integer;
  src, dst: PColor32;
  tmp: TImage32;
begin
  if IsEmpty then Exit;

  BeginUpdate;
  tmp := TImage32.create(Self);
  try
    SetSize(Height, Width);
    xx := (width - 1) * Height;
    dst := PixelBase;
    for y := 0 to Height -1 do
    begin
      src := @tmp.Pixels[xx + y];
      for x := 0 to Width -1 do
      begin
        dst^ := src^;
        inc(dst); dec(src, Height);
      end;
    end;
  finally
    tmp.Free;
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure TImage32.RotateRight90;
var
  x,y: Integer;
  src, dst: PColor32;
  tmp: TImage32;
begin
  if IsEmpty then Exit;

  BeginUpdate;
  tmp := TImage32.create(Self);
  try
    SetSize(Height, Width);
    dst := PixelBase;
    for y := 0 to Height -1 do
    begin
      src := @tmp.Pixels[Height -1 - y];
      for x := 0 to Width -1 do
      begin
        dst^ := src^;
        inc(dst); inc(src, Height);
      end;
    end;
  finally
    tmp.Free;
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure TImage32.Rotate180;
var
  x,y: Integer;
  src, dst: PColor32;
  tmp: TImage32;
begin
  if IsEmpty then Exit;
  tmp := TImage32.create(Self);
  try
    dst := PixelBase;
    src := @tmp.Pixels[Width * Height -1];
    for y := 0 to Height -1 do
    begin
      for x := 0 to Width -1 do
      begin
        dst^ := src^;
        inc(dst); dec(src);
      end;
    end;
  finally
    tmp.Free;
  end;
  Changed;
end;
//------------------------------------------------------------------------------

function TImage32.GetColorCount: Integer;
var
  allColors: PByteArray;
  i: Integer;
  c: PColor32;
const
  cube256 = 256 * 256 * 256;
begin
  result := 0;
  if IsEmpty then Exit;
  if fColorCount > 0 then
  begin
    result := fColorCount;
    Exit;
  end;
  //because 'allColors' uses quite a chunk of memory, it's
  //allocated on the heap rather than the stack
  allColors := AllocMem(cube256); //nb: zero initialized
  try
    c := PixelBase;
    for i := 0 to Width * Height -1 do
    begin
      //ignore colors with signifcant transparency
      if (c^ shr 24) > $80 then
        allColors[c^ and $FFFFFF] := 1;
      inc(c);
    end;
    for i := 0 to cube256 -1 do
      if allColors[i] = 1 then inc(Result);
  finally
    FreeMem(allColors);
  end;
  fColorCount := Result; //avoids repeating the above unnecessarily
end;
//------------------------------------------------------------------------------

function TImage32.GetHasTransparency: Boolean;
var
  i: Integer;
  pc: PARGB;
begin
  result := true;
  If IsEmpty then Exit;
  pc := PARGB(PixelBase);
  for i := 0 to Width * Height -1 do
  begin
    if pc.A < 255 then Exit;
    inc(pc);
  end;
  result := false;
end;
//------------------------------------------------------------------------------

function TImage32.SaveToFile(filename: string): Boolean;
var
  fileFormatClass: TImageFormatClass;
begin
  result := false;
  if IsEmpty or (length(filename) < 5) then Exit;
  //use the process's current working directory if no path supplied ...
  if ExtractFilePath(filename) = '' then
    filename := GetCurrentDir + '\'+ filename;
  fileFormatClass := GetImageFormatClass(ExtractFileExt(filename));
  if assigned(fileFormatClass) then
    with fileFormatClass.Create do
    try
      result := SaveToFile(filename, self);
    finally
      free;
    end;
end;
//------------------------------------------------------------------------------

function TImage32.SaveToStream(stream: TStream; const FmtExt: string): Boolean;
var
  fileFormatClass: TImageFormatClass;
begin
  result := false;
  fileFormatClass := GetImageFormatClass(FmtExt);
  if assigned(fileFormatClass) then
    with fileFormatClass.Create do
    try
      SaveToStream(stream, self);
      result := true;
    finally
      free;
    end;
end;
//------------------------------------------------------------------------------

function TImage32.LoadFromFile(const filename: string): Boolean;
var
  image32FileFmtClass: TImageFormatClass;
begin
  image32FileFmtClass := GetImageFormatClass(ExtractFileExt(filename));
  result := assigned(image32FileFmtClass);
  if not result then Exit;

  with image32FileFmtClass.Create do
  try
    result := LoadFromFile(filename, self);
  finally
    free;
  end;
end;
//------------------------------------------------------------------------------

function TImage32.LoadFromStream(stream: TStream; const FmtExt: string): Boolean;
var
  image32FileFmtClass: TImageFormatClass;
  fmt: string;
begin
  if FmtExt = '' then
    fmt := TImage32.GetExtFromImageStream(stream) else
    fmt := FmtExt;
  image32FileFmtClass := GetImageFormatClass(fmt);
  result := assigned(image32FileFmtClass);
  if not result then Exit;
  with image32FileFmtClass.Create do
  try
    result := LoadFromStream(stream, self);
  finally
    free;
  end;
end;
//------------------------------------------------------------------------------

function TImage32.GetPixel(x, y: Integer): TColor32;
begin
  if (x < 0) or (x >= Width) or (y < 0) or (y >= Height) then
    result := clNone32 else
    result := fPixels[y * width + x];
end;
//------------------------------------------------------------------------------

procedure TImage32.SetPixel(x,y: Integer; color: TColor32);
begin
  if (x < 0) or (x >= Width) or (y < 0) or (y >= Height) then Exit;
  fPixels[y * width + x] := color;
  //nb: no notify event here
end;
//------------------------------------------------------------------------------

function TImage32.GetIsBlank: Boolean;
var
  i: integer;
  pc: PARGB;
begin
  result := IsEmpty;
  if result then Exit;
  pc := PARGB(PixelBase);
  for i := 0 to width * height -1 do
  begin
    if pc.A > 0 then Exit;
    inc(pc);
  end;
  result := true;
end;
//------------------------------------------------------------------------------

function TImage32.GetIsEmpty: Boolean;
begin
  result := fPixels = nil;
end;
//------------------------------------------------------------------------------

function TImage32.GetPixelBase: PColor32;
begin
  if IsEmpty then result := nil
  else result := @fPixels[0];
end;
//------------------------------------------------------------------------------

function TImage32.GetPixelRow(row: Integer): PColor32;
begin
  if IsEmpty then result := nil
  else result := @fPixels[row * Width];
end;
//------------------------------------------------------------------------------

procedure TImage32.CopyInternal(src: TImage32;
  const srcRec, dstRec: TRect; blendFunc: TBlendFunction);
var
  i, j, srcRecWidth: Integer;
  s, d: PColor32;
begin
  srcRecWidth := srcRec.Right - srcRec.Left;
  s := @src.Pixels[srcRec.Top * src.Width + srcRec.Left];
  d := @Pixels[dstRec.top * Width + dstRec.Left];

  if assigned(blendFunc) then
    for i := srcRec.Top to srcRec.Bottom -1 do
    begin
      for j := 1 to srcRecWidth do
      begin
        d^ := blendFunc(d^, s^);
        inc(s); inc(d);
      end;
      inc(s, src.Width - srcRecWidth);
      inc(d, Width - srcRecWidth);
    end
  else
    //simply overwrite src with dst (ie without blending)
    for i := srcRec.Top to srcRec.Bottom -1 do
    begin
      move(s^, d^, srcRecWidth * SizeOf(TColor32));
      inc(s, src.Width);
      inc(d, Width);
    end;
end;
//------------------------------------------------------------------------------

function TImage32.Copy(src: TImage32; srcRec, dstRec: TRect): Boolean;
begin
  Result := CopyBlend(src, srcRec, dstRec, nil);
end;
//------------------------------------------------------------------------------

function TImage32.CopyBlend(src: TImage32; srcRec, dstRec: TRect;
  blendFunc: TBlendFunction): Boolean;
var
  tmp: TImage32;
  srcRecClipped, dstRecClipped, dummy: TRect;
  scale, scaleSrc, scaleDst: TPointD;
begin
  result := false;
  if IsEmptyRect(srcRec) or IsEmptyRect(dstRec) then Exit;
  IntersectRect(srcRecClipped, srcRec, src.Bounds);

  //get the scaling amount (if any) before
  //dstRec might be adjusted due to clipping ...
  scale.X := RectWidth(dstRec)/RectWidth(srcRec);
  scale.Y := RectHeight(dstRec)/RectHeight(srcRec);

  //check if the source rec has been clipped ...
  if not RectsEqual(srcRecClipped, srcRec) then
  begin
    if IsEmptyRect(srcRecClipped) then Exit;
    //the source has been clipped so clip the destination too ...
    scaleSrc.X := RectWidth(srcRecClipped)/RectWidth(srcRec);
    scaleSrc.Y := RectHeight(srcRecClipped)/RectHeight(srcRec);
    ScaleRect(dstRec, scaleSrc);
    Types.OffsetRect(dstRec,
      srcRecClipped.Left - srcRec.Left,
      srcRecClipped.Top - srcRec.Top);
  end;

  if (scale.X <> 1.0) or (scale.Y <> 1.0) then
  begin
    //scale source (tmp) to the destination then call CopyBlend() again ...
    tmp := TImage32.Create(src, srcRecClipped);
    try
      tmp.Scale(scale.X, scale.Y);
      result := CopyBlend(tmp, tmp.Bounds, dstRec, blendFunc);
    finally
      tmp.Free;
    end;
    Exit;
  end;

  IntersectRect(dstRecClipped, dstRec, Bounds);
  if IsEmptyRect(dstRecClipped) then Exit;

  //there's no scaling if we get here, but further clipping may be needed if
  //the destination rec is partially outside the destination image's bounds

  if not RectsEqual(dstRecClipped, dstRec) then
  begin
    //the destination rec has been clipped so clip the source too ...
    scaleDst.X := RectWidth(dstRecClipped)/RectWidth(dstRec);
    scaleDst.Y := RectHeight(dstRecClipped)/RectHeight(dstRec);
    ScaleRect(srcRecClipped, scaleDst);
    Types.OffsetRect(srcRecClipped,
      dstRecClipped.Left - dstRec.Left,
      dstRecClipped.Top - dstRec.Top);
  end;

  //when copying to self and srcRec & dstRec overlap then
  //copy srcRec to a temporary image and use it as the source ...
  if (src = self) and
    IntersectRect(dummy, srcRecClipped, dstRecClipped) then
  begin
    tmp := TImage32.Create(self, srcRecClipped);
    try
      result := src.CopyBlend(tmp, tmp.Bounds, dstRecClipped, blendFunc);
    finally
      tmp.Free;
    end;
    Exit;
  end;

  CopyInternal(src, srcRecClipped, dstRecClipped, blendFunc);
  result := true;
  Changed;
end;
//------------------------------------------------------------------------------

function TImage32.LoadFromResource(const resName: string; resType: PChar): Boolean;
var
  resStream: TResourceStream;
begin
  resStream := CreateResourceStream(resName, resType);
  try
    Result := assigned(resStream) and
      LoadFromStream(resStream, '');
  finally
    resStream.Free;
  end;
end;
//------------------------------------------------------------------------------

{$IFDEF MSWINDOWS}
procedure TImage32.CopyFromDC(srcDc: HDC; const srcRect: TRect);
var
  bi: TBitmapInfoHeader;
  bm, oldBm: HBitmap;
  dc, memDc: HDC;
  pixels: Pointer;
  w,h: integer;
begin
  BeginUpdate;
  try
    w := RectWidth(srcRect);
    h := RectHeight(srcRect);
    SetSize(w, h);
    bi := Get32bitBitmapInfoHeader(w, h);
    dc := GetDC(0);
    memDc := CreateCompatibleDC(dc);
    try
      bm := CreateDIBSection(dc,
        PBITMAPINFO(@bi)^, DIB_RGB_COLORS, pixels, 0, 0);
      if bm = 0 then Exit;
      try
        oldBm := SelectObject(memDc, bm);
        BitBlt(memDc, 0, 0, w, h, srcDc, srcRect.Left,srcRect.Top, SRCCOPY);
        Move(pixels^, fPixels[0], w * h * sizeOf(TColor32));
        SelectObject(memDc, oldBm);
      finally
        DeleteObject(bm);
      end;
    finally
      DeleteDc(memDc);
      ReleaseDc(0, dc);
    end;
    SetAlpha(255);
    FlipVertical;
  finally
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure TImage32.CopyToDc(dstDc: HDC;
  x,y: Integer; transparent: Boolean; bkColor: TColor32);
begin
  CopyToDc(Bounds, Types.Rect(x,y, x+Width, y+Height),
    dstDc, transparent, bkColor);
end;
//------------------------------------------------------------------------------

procedure TImage32.CopyToDc(const srcRect: TRect; dstDc: HDC;
  x: Integer = 0; y: Integer = 0;
  transparent: Boolean = true; bkColor: TColor32 = 0);
begin
  CopyToDc(srcRect, Types.Rect(x,y, x +RectWidth(srcRect),
    y +RectHeight(srcRect)), dstDc, transparent, bkColor);
end;
//------------------------------------------------------------------------------

procedure TImage32.CopyToDc(const srcRect, dstRect: TRect; dstDc: HDC;
  transparent: Boolean = true; bkColor: TColor32 = clNone32);
var
  x,y, wSrc ,hSrc, wDest, hDest: integer;
  rec: TRect;
  tmp: TImage32;
  bi: TBitmapInfoHeader;
  bm, oldBm: HBitmap;
  dibBits: Pointer;
  memDc: HDC;
  hasTransparency: Boolean;
  bf: BLENDFUNCTION;
begin
  IntersectRect(rec, srcRect, Bounds);
  if IsEmpty or IsEmptyRect(rec) then Exit;
  wSrc := RectWidth(rec);
  hSrc := RectHeight(rec);
  wDest := RectWidth(dstRect);
  hDest := RectHeight(dstRect);
  tmp := TImage32.create;
  try
    tmp.SetSize(wSrc, hSrc);
    tmp.CopyInternal(self, rec, tmp.Bounds, nil);
    x := dstRect.Left;
    y := dstRect.Top;
    inc(x, rec.Left - srcRect.Left);
    inc(y, rec.Top - srcRect.Top);

    bi := Get32bitBitmapInfoHeader(wSrc, hSrc);

    tmp.FlipVertical; //DIB sections store pixels Y-inverted.
    hasTransparency :=
      transparent and (TARGB(bkColor).A < 255) and tmp.HasTransparency;
    tmp.Premultiply;  //this is required for DIB sections
    if bkColor <> 0 then
      tmp.SetBackgroundColor(bkColor);
    memDc := CreateCompatibleDC(0);
    try
      bm := CreateDIBSection(memDc, PBITMAPINFO(@bi)^,
        DIB_RGB_COLORS, dibBits, 0, 0);
      if bm = 0 then Exit;
      try
        Move(tmp.PixelBase^, dibBits^, wSrc * hSrc * SizeOf(TColor32));
        oldBm := SelectObject(memDC, bm);
        if HasTransparency then
        begin
          bf.BlendOp := AC_SRC_OVER;
          bf.BlendFlags := 0;
          bf.SourceConstantAlpha := 255;
          bf.AlphaFormat := AC_SRC_ALPHA;
          AlphaBlend(dstDc, x,y, wDest,hDest, memDC, 0,0, wSrc,hSrc, bf);
        end
        else if (wDest = wSrc) and (hDest = hSrc) then
          BitBlt(dstDc, x,y, wSrc, hSrc, memDc, 0,0, SRCCOPY)
        else
          StretchBlt(dstDc, x,y, wDest,hDest, memDc, 0,0, wSrc,hSrc, SRCCOPY);

        SelectObject(memDC, oldBm);
      finally
        DeleteObject(bm);
      end;
    finally
      DeleteDc(memDc);
    end;
  finally
    tmp.Free;
  end;
end;
//------------------------------------------------------------------------------
{$ENDIF}

function TImage32.CopyToClipBoard: Boolean;
var
  i: Integer;
  formatClass: TImageFormatClass;
begin
  //Sadly with CF_DIB (and even CF_DIBV5) clipboard formats, transparency is
  //usually lost, so we'll copy all available formats including CF_PNG, that
  //is if it's registered.
  result := not IsEmpty;
  if not result then Exit;
  result := false;

  for i := ImageFormatClassList.Count -1 downto 0 do
  begin
    formatClass := PImgFmtRec(ImageFormatClassList[i]).Obj;
    if not formatClass.CanCopyToClipboard then Continue;
    with formatClass.Create do
    try
      if CopyToClipboard(self) then result := true;
    finally
      free;
    end;
  end;
end;
//------------------------------------------------------------------------------

class function TImage32.CanPasteFromClipBoard: Boolean;
var
  i: Integer;
  formatClass: TImageFormatClass;
begin
  result := false;
  for i := ImageFormatClassList.Count -1 downto 0 do
  begin
    formatClass := PImgFmtRec(ImageFormatClassList[i]).Obj;
    if formatClass.CanPasteFromClipboard then
    begin
      result := true;
      Exit;
    end;
  end;
end;
//------------------------------------------------------------------------------

function TImage32.PasteFromClipBoard: Boolean;
var
  i: Integer;
  formatClass: TImageFormatClass;
begin
  result := false;
  for i := ImageFormatClassList.Count -1 downto 0 do
  begin
    formatClass := PImgFmtRec(ImageFormatClassList[i]).Obj;
    if not formatClass.CanPasteFromClipboard then Continue;

    with formatClass.Create do
    try
      result := PasteFromClipboard(self);
      if not Result then Continue;
    finally
      free;
    end;
    Changed;
    Break;
  end;
end;
//------------------------------------------------------------------------------

procedure TImage32.ConvertToBoolMask(reference: TColor32; tolerance: integer;
  colorFunc: TCompareFunction; maskBg: TColor32; maskFg: TColor32);
var
  i: Integer;
  mask: TArrayOfByte;
  c: PColor32;
  b: PByte;
begin
  if IsEmpty then Exit;
  mask := GetBoolMask(self, reference, colorFunc, tolerance);
  c := PixelBase;
  b := @mask[0];
  for i := 0 to Width * Height -1 do
  begin
    {$IFDEF PBYTE}
    if b^ = 0 then c^ := maskBg else c^ := maskFg;
    {$ELSE}
    if b^ = #0 then c^ := maskBg else c^ := maskFg;
    {$ENDIF}
    inc(c); inc(b);
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.ConvertToAlphaMask(reference: TColor32;
  colorFunc: TCompareFunctionEx);
var
  i: Integer;
  mask: TArrayOfByte;
  c: PColor32;
  b: PByte;
begin
  if IsEmpty then Exit;
  mask := GetByteMask(self, reference, colorFunc);
  c := PixelBase;
  b := @mask[0];
  for i := 0 to Width * Height -1 do
  begin
    {$IFDEF PBYTE}
    c^ := b^ shl 24;
    {$ELSE}
    c^ := Ord(b^) shl 24;
    {$ENDIF}
    inc(c); inc(b);
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.FlipVertical;
var
  i: Integer;
  a: TArrayOfColor32;
  src, dst: PColor32;
begin
  if IsEmpty then Exit;
  SetLength(a, fWidth * fHeight);
  src := @fPixels[(height-1) * width];
  dst := @a[0];
  for i := 0 to fHeight -1 do
  begin
    move(src^, dst^, fWidth * SizeOf(TColor32));
    dec(src, fWidth); inc(dst, fWidth);
  end;
  fPixels := a;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.FlipHorizontal;
var
  i,j, widthLess1: Integer;
  a: TArrayOfColor32;
  row: PColor32;
begin
  if IsEmpty then Exit;
  SetLength(a, fWidth);
  widthLess1 := fWidth -1;
  row := @fPixels[(height-1) * width]; //top row
  for i := 0 to fHeight -1 do
  begin
    move(row^, a[0], fWidth * SizeOf(TColor32));
    for j := 0 to widthLess1 do
    begin
      row^ := a[widthLess1 - j];
      inc(row);
    end;
    dec(row, fWidth *2);
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.PreMultiply;
var
  i: Integer;
  c: PARGB;
begin
  if IsEmpty or fIsPremultiplied then Exit;
  fIsPremultiplied := true;
  c := PARGB(PixelBase);
  for i := 0 to Width * Height -1 do
  begin
    if c.A > 0 then
    begin
      c.R  := MulBytes(c.R, c.A);
      c.G  := MulBytes(c.G, c.A);
      c.B  := MulBytes(c.B, c.A);
    end
    else
      c.Color := 0;
    inc(c);
  end;
  //nb: no OnChange notify event here
end;
//------------------------------------------------------------------------------

procedure TImage32.SetRGB(rgbColor: TColor32);
var
  rgb: TARGB absolute rgbColor;
  r,g,b: Byte;
  i: Integer;
  pc: PARGB;
begin
  //this method leaves the alpha channel untouched
  if IsEmpty then Exit;
  r := rgb.R; g := rgb.G; b := rgb.B;
  pc := PARGB(PixelBase);
  for i := 0 to Width * Height -1 do
  begin
    pc.R := r;
    pc.G := g;
    pc.B := b;
    inc(pc);
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.SetAlpha(alpha: Byte);
var
  i: Integer;
  c: PARGB;
begin
  //this method only changes the alpha channel
  if IsEmpty then Exit;
  c := PARGB(PixelBase);
  for i := 0 to Width * Height -1 do
  begin
    c.A := alpha;
    inc(c);
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.Grayscale;
begin
  AdjustSaturation(-100);
end;
//------------------------------------------------------------------------------

procedure TImage32.InvertColors;
var
  pc: PARGB;
  i: Integer;
begin
  pc := PARGB(PixelBase);
  for i := 0 to Width * Height -1 do
  begin
    pc.R := 255 - pc.R;
    pc.G := 255 - pc.G;
    pc.B := 255 - pc.B;
    inc(pc);
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.InvertAlphas;
var
  pc: PARGB;
  i: Integer;
begin
  pc := PARGB(PixelBase);
  for i := 0 to Width * Height -1 do
  begin
    pc.A := 255 - pc.A;
    inc(pc);
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.Tile(newWidth, newHeight: integer;
  style: TTileFillStyle = tfsRepeat);
var
  i,j, w,h, w2,h2: integer;
  pc1, pc2: PColor32;
  tmp: TImage32;
begin
  w := Min(Width, newWidth); h := Min(Height, newHeight);
  w2 := Min(w*2, newWidth);
  h2 := Min(h*2, newHeight);

  //do the first 4 tile square (as further tiling will be simple copies)
  tmp := TImage32.Create(self, Types.Rect(0, 0, w, h));
  try
    SetSize(newWidth, newHeight);
    for i := 0 to h -1 do
    begin
      pc1 := tmp.PixelRow[i];
      pc2 := PixelRow[i];
      Move(pc1^, pc2^, w * SizeOf(TColor32));
    end;

    case style of
      tfsMirrorHorz: tmp.FlipHorizontal;
      tfsMirrorVert: tmp.FlipVertical;
      tfsRotate180: tmp.Rotate180;
    end;

    if w2 > w then
    begin
      for i := 0 to h -1 do
      begin
        pc1 := tmp.PixelRow[i];
        pc2 := @Pixels[i * newWidth + w];
        Move(pc1^, pc2^, (w2 - w) * SizeOf(TColor32));
      end;
    end;

    if h2 > h then
    begin
      for i := 0 to w2 -1 do
      begin
        pc1 := @Pixels[i];
        pc2 := @Pixels[h * newWidth + i];
        for j := h to h2 -1 do
        begin
          pc2^ := pc1^;
          inc(pc1, newWidth);
          inc(pc2, newWidth);
        end;
      end;
    end;
  finally
    tmp.Free;
  end;

  //now straight copy the first 4 tile block to fill the rest of the image
  w := w2; h := h2;
  while (w2 < newWidth) do
  begin
    j := Min(w2 + w, newWidth);
    for i := 0 to h -1 do
    begin
      pc1 := PixelRow[i];
      pc2 := IncPColor32(pc1, w2);
      Move(pc1^, pc2^, (j - w2) * SizeOf(TColor32));
    end;
    inc(w2, w);
  end;

  while (h2 < newHeight) do
  begin
    j := Min(h2 + h, newHeight);
    for i := h2 to j -1 do
    begin
      pc1 := PixelRow[i-h2];
      pc2 := PixelRow[i];
      Move(pc1^, pc2^, newWidth * SizeOf(TColor32));
    end;
    inc(h2, h);
  end;
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.AdjustHue(percent: Integer);
var
  i: Integer;
  tmpImage: TArrayofHSL;
  lut: array [byte] of byte;
begin
  percent := percent mod 100;
  if percent < 0 then inc(percent, 100);
  percent := Round(percent * 255 / 100);
  if (percent = 0) or IsEmpty then Exit;
  for i := 0 to 255 do lut[i] := (i + percent) mod 255;
  tmpImage := ArrayOfColor32ToArrayHSL(fPixels);
  for i := 0 to high(tmpImage) do
    tmpImage[i].hue := lut[ tmpImage[i].hue ];
  fPixels := ArrayOfHSLToArrayColor32(tmpImage);
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.AdjustLuminance(percent: Integer);
var
  i: Integer;
  tmpImage: TArrayofHSL;
  pc: double;
  lut: array [byte] of byte;
begin
  if (percent = 0) or IsEmpty then Exit;
  percent := percent mod 101;
  pc := percent / 100;
  if pc > 0 then
    for i := 0 to 255 do lut[i] := Round(i + (255 - i) * pc)
  else
    for i := 0 to 255 do lut[i] := Round(i + (i * pc));

  tmpImage := ArrayOfColor32ToArrayHSL(fPixels);
  for i := 0 to high(tmpImage) do
    tmpImage[i].lum := lut[ tmpImage[i].lum ];
  fPixels := ArrayOfHSLToArrayColor32(tmpImage);
  Changed;
end;
//------------------------------------------------------------------------------

procedure TImage32.AdjustSaturation(percent: Integer);
var
  i: Integer;
  tmpImage: TArrayofHSL;
  lut: array [byte] of byte;
  pc: double;
begin
  if (percent = 0) or IsEmpty then Exit;
  percent := percent mod 101;
  pc := percent / 100;
  if pc > 0 then
    for i := 0 to 255 do lut[i] := Round(i + (255 - i) * pc)
  else
    for i := 0 to 255 do lut[i] := Round(i + (i * pc));

  tmpImage := ArrayOfColor32ToArrayHSL(fPixels);
  for i := 0 to high(tmpImage) do
    tmpImage[i].sat := lut[ tmpImage[i].sat ];
  fPixels := ArrayOfHSLToArrayColor32(tmpImage);
  Changed;
end;
//------------------------------------------------------------------------------

function TImage32.CropTransparentPixels: TRect;
var
  x,y, x1,x2,y1,y2: Integer;
  found: Boolean;
begin
  y1 := 0; y2 := 0;
  found := false;
  for y := 0 to Height -1 do
  begin
    for x := 0 to Width -1 do
      if TARGB(fPixels[y * Width + x]).A > 0 then
      begin
        y1 := y;
        found := true;
        break;
      end;
    if found then break;
  end;

  if not found then
  begin
    SetSize(0, 0);
    Exit;
  end;

  found := false;
  for y := Height -1 downto 0 do
  begin
    for x := 0 to Width -1 do
      if TARGB(fPixels[y * Width + x]).A > 0 then
      begin
        y2 := y;
        found := true;
        break;
      end;
    if found then break;
  end;

  x1 := Width; x2 := 0;
  for y := y1 to y2 do
    for x := 0 to Width -1 do
      if TARGB(fPixels[y * Width + x]).A > 0 then
      begin
        if x < x1 then x1 := x;
        if x > x2 then x2 := x;
      end;

  Result := Types.Rect(x1, y1, x2+1, y2+1);
  Crop(Result);
end;
//------------------------------------------------------------------------------

procedure TImage32.Rotate(angleRads: double);
var
  tmp: TArrayOfColor32;
  x, y, xi, yi, newWidth, newHeight: Integer;
  sinA, cosA: extended;
  dx, dy: double;
  pt, center: TPointD;
  rec: TRectD;
  dstColor: PColor32;
const
  TwoPi = 2 * pi;
begin
  if ClockwiseRotationIsAnglePositive then
    angleRads := -angleRads;

  //nb: There's no point rotating about a specific point
  //since the rotated image will be recentered.

  NormalizeAngle(angleRads);
  if IsEmpty or (angleRads = 0) then Exit;

  Math.SinCos(angleRads, sinA, cosA);
  if abs(sinA) < 0.000001 then
  begin
    Rotate180; //because we've excluded 0 & 360 deg angles
    Exit;
  end
  else if sinA > 0.999999 then
  begin
    RotateRight90;
    Exit;
  end
  else if sinA < -0.999999 then
  begin
    RotateLeft90;
    Exit;
  end;

  rec := RectD(Bounds);
  rec := GetRotatedRectBounds(rec, angleRads);
  newWidth := Ceil(rec.Right - rec.Left);
  newHeight := Ceil(rec.Bottom - rec.Top);

  center := PointD(rec.Width/2, rec.Height/2);
  SetLength(tmp, newWidth * newHeight);
  dstColor := @tmp[0];
  with MidPoint do
  begin
    dx := center.X - X;
    dy := center.Y - Y;
  end;
  if fAntiAliase then
  begin
    for y := 0 to newHeight -1 do
      for x := 0 to newWidth -1 do
      begin
        pt := PointD(x, y);
        RotatePt(pt, center, sinA, cosA);
        xi := Round((pt.X - dx) *256);
        yi := Round((pt.Y - dy) *256);
        dstColor^ := GetWeightedPixel(self, xi, yi);
        inc(dstColor);
      end;
  end else
  begin
    for y := 0 to newHeight -1 do
      for x := 0 to newWidth -1 do
      begin
        pt := PointD(x, y);
        RotatePt(pt, center, sinA, cosA);
        xi := Round(pt.X - dx);
        yi := Round(pt.Y - dy);
        if (xi < 0) or (xi >= Width) or (yi < 0) or (yi >= Height) then
          dstColor^ := clNone32
        else
          dstColor^ := fPixels[xi + yi * Width];
        inc(dstColor);
      end;
  end;

  BeginUpdate;
  try
    SetSize(newWidth, newHeight);
    fPixels := tmp;
  finally
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure TImage32.RotateRect(const rec: TRect;
  angleRads: single; eraseColor: TColor32 = 0);
var
  tmp: TImage32;
  rec2: TRect;
  recWidth, recHeight: integer;
begin
  if ClockwiseRotationIsAnglePositive then
    angleRads := -angleRads;

  recWidth := rec.Right - rec.Left;
  recHeight := rec.Bottom - rec.Top;
  //create a tmp image with a copy of the pixels inside rec ...
  tmp := TImage32.Create(self, rec);
  try
    tmp.Rotate(angleRads);
    //since rotating also resizes, get a centered
    //(clipped) rect of the rotated pixels ...
    rec2.Left := (tmp.Width - recWidth) div 2;
    rec2.Top := (tmp.Height - recHeight) div 2;
    rec2.Right := rec2.Left + recWidth;
    rec2.Bottom := rec2.Top + recHeight;
    //finally move the rotated rec back to the image ...
    FillRect(rec, eraseColor);
    CopyBlend(tmp, rec2, rec);
  finally
    tmp.Free;
  end;
end;
//------------------------------------------------------------------------------

procedure TImage32.Skew(dx,dy: double);
var
  i,j, newWidth, newHeight: integer;
  x,y: double;
  tmpPxls: TArrayOfColor32;
  pcDst: PColor32;
begin
  if IsEmpty or ((dx = 0) and (dy = 0)) then Exit;
  newWidth := Width + Ceil(Abs(dx));
  newHeight := Height + Ceil(Abs(dy));
  SetLength(tmpPxls, newWidth * newHeight);
  pcDst := @tmpPxls[0];
  for i := 0 to newHeight - 1 do
    for j := 0 to newWidth - 1 do
    begin
      x := Min(0,  dx) + j - i * dx/newHeight;
      y := Min(0, -dy) + j * dy/newWidth + i;
      pcDst^ := GetWeightedPixel(self, Round(x*$100), Round(y*$100));
      inc(pcDst);
    end;

  BeginUpdate;
  try
    SetSize(newWidth, newHeight);
    fPixels := tmpPxls;
  finally
    EndUpdate;
  end;
end;
//------------------------------------------------------------------------------

procedure TImage32.ScaleAlpha(scale: double);
var
  i: Integer;
  pb: PARGB;
begin
  pb := PARGB(PixelBase);
  for i := 0 to Width * Height - 1 do
  begin
    pb.A := ClampByte(Round(pb.A * scale));
    inc(pb);
  end;
  Changed;
end;

//------------------------------------------------------------------------------
// TImageList32
//------------------------------------------------------------------------------

constructor TImageList32.Create;
begin
{$IFDEF XPLAT_GENERICS}
  fList := TList<TImage32>.Create;
{$ELSE}
  fList := TList.Create;
{$ENDIF}
  fIsImageOwner := true;
end;
//------------------------------------------------------------------------------

destructor TImageList32.Destroy;
begin
  Clear;
  fList.Free;
  inherited;
end;
//------------------------------------------------------------------------------

function TImageList32.Count: integer;
begin
  result := fList.Count;
end;
//------------------------------------------------------------------------------

procedure TImageList32.Clear;
var
  i: integer;
begin
  if IsImageOwner then
    for i := 0 to fList.Count -1 do
      TImage32(fList[i]).Free;
  fList.Clear;
end;
//------------------------------------------------------------------------------

function TImageList32.GetImage(index: integer): TImage32;
begin
  result := TImage32(fList[index]);
end;
//------------------------------------------------------------------------------

procedure TImageList32.SetImage(index: integer; img: TIMage32);
begin
  if fIsImageOwner then TImage32(fList[index]).Free;
  fList[index] := img;
end;
//------------------------------------------------------------------------------

function TImageList32.GetLast: TImage32;
begin
  if Count = 0 then Result := nil
  else Result := TImage32(fList[Count -1]);
end;
//------------------------------------------------------------------------------

procedure TImageList32.Add(image: TImage32);
begin
  fList.Add(image);
end;
//------------------------------------------------------------------------------

procedure TImageList32.Insert(index: integer; image: TImage32);
begin
  fList.Insert(index, image);
end;
//------------------------------------------------------------------------------

procedure TImageList32.Move(currentIndex, newIndex: integer);
begin
  fList.Move(currentIndex, newIndex);
end;
//------------------------------------------------------------------------------

procedure TImageList32.Delete(index: integer);
begin
  if fIsImageOwner then TImage32(fList[index]).Free;
  fList.Delete(index);
end;

//------------------------------------------------------------------------------
// TWeightedColor record
//------------------------------------------------------------------------------

procedure TWeightedColor.Reset;
begin
  fAddCount := 0;
  fAlphaTot := 0;
  fColorTotR := 0;
  fColorTotG := 0;
  fColorTotB := 0;
end;
//------------------------------------------------------------------------------

procedure TWeightedColor.AddWeight(weight: Integer);
begin
  inc(fAddCount, weight);
end;
//------------------------------------------------------------------------------

procedure TWeightedColor.Add(c: TColor32; weight: Integer);
var
  a: Integer;
  argb: TARGB absolute c;
begin
  inc(fAddCount, weight);
  a := weight * argb.A;
  if a = 0 then Exit;
  inc(fAlphaTot, a);
  inc(fColorTotB, (a * argb.B));
  inc(fColorTotG, (a * argb.G));
  inc(fColorTotR, (a * argb.R));
end;
//------------------------------------------------------------------------------

procedure TWeightedColor.Subtract(c: TColor32; weight: Integer);
var
  a: Integer;
  argb: TARGB absolute c;
begin
  dec(fAddCount, weight);
  a := weight * argb.A;
  if a = 0 then Exit;
  dec(fAlphaTot, a);
  dec(fColorTotB, (a * argb.B));
  dec(fColorTotG, (a * argb.G));
  dec(fColorTotR, (a * argb.R));
end;
//------------------------------------------------------------------------------

function TWeightedColor.GetColor: TColor32;
var
  a: byte;
  halfAlphaTot: Integer;
  argb: TARGB absolute result;
begin
  result := clNone32;
  if (fAlphaTot <= 0) or (fAddCount <= 0) then Exit;
  a := DivRound(fAlphaTot, fAddCount);
  if (a = 0) then Exit;
  argb.A := a;
  halfAlphaTot := fAlphaTot div 2;
  //nb: alpha weighting is applied to colors when added
  //so we now need to div by fAlphaTot (with rounding) here ...
  argb.R := ClampByte((fColorTotR + halfAlphaTot) div fAlphaTot);
  argb.G := ClampByte((fColorTotG + halfAlphaTot) div fAlphaTot);
  argb.B := ClampByte((fColorTotB + halfAlphaTot) div fAlphaTot);
end;

//------------------------------------------------------------------------------
// TImageFormat methods
//------------------------------------------------------------------------------

function TImageFormat.LoadFromFile(const filename: string;
  img32: TImage32): Boolean;
var
  fs: TFileStream;
begin
  result := FileExists(filename);
  if not result then Exit;
  fs := TFileStream.Create(filename, fmOpenRead or fmShareDenyWrite);
  try
    Result := LoadFromStream(fs, img32);
  finally
    fs.Free;
  end;
end;
//------------------------------------------------------------------------------

function TImageFormat.SaveToFile(const filename: string;
  img32: TImage32): Boolean;
var
  fs: TFileStream;
begin
  result := (pos('.', filename) = 1) or
    DirectoryExists(ExtractFilePath(filename));
  if not result then Exit;

  fs := TFileStream.Create(filename, fmCreate);
  try
    SaveToStream(fs, img32);
  finally
    fs.Free;
  end;
end;
//------------------------------------------------------------------------------

class function TImageFormat.CanCopyToClipboard: Boolean;
begin
  Result := false;
end;

//------------------------------------------------------------------------------
// Initialization and Finalization functions
//------------------------------------------------------------------------------

procedure MakeBlendTables;
var
  i,j: Integer;
begin
  for j := 0 to 255 do MulTable[0, j] := 0;
  for i := 0 to 255 do MulTable[i, 0] := 0;
  for j := 0 to 255 do DivTable[0, j] := 0;
  for i := 0 to 255 do DivTable[i, 0] := 0;
  for i := 1 to 255 do
    for j := 1 to 255 do
    begin
      MulTable[i, j] := Round(i * j * div255);
      if i >= j then
        DivTable[i, j] := 255 else
        DivTable[i, j] := Round(i * $FF / j);
    end;
end;
//------------------------------------------------------------------------------

{$IFDEF MSWINDOWS}
procedure GetScreenScale;
var
  dc: HDC;
  ScreenPixelsY: integer;
begin
  dc := GetDC(0);
  try
    ScreenPixelsY := GetDeviceCaps(dc, LOGPIXELSY);
    ScreenScale := ScreenPixelsY / 96;
  finally
    ReleaseDC(0, dc);
  end;
end;
{$ENDIF}
//------------------------------------------------------------------------------

procedure CleanUpImageFormatClassList;
var
  i: integer;
begin
  for i := ImageFormatClassList.Count -1 downto 0 do
    Dispose(PImgFmtRec(ImageFormatClassList[i]));
  ImageFormatClassList.Free;
end;
//------------------------------------------------------------------------------

initialization

{$IFDEF XPLAT_GENERICS}
  ImageFormatClassList := TList<PImgFmtRec>.Create;
{$ELSE}
  ImageFormatClassList := TList.Create;
{$ENDIF}

  MakeBlendTables;

{$IFDEF MSWINDOWS}
  GetScreenScale;
{$ENDIF}

finalization
  CleanUpImageFormatClassList;

end.
