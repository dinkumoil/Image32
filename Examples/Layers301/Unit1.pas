unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls,
  Forms, Math, Types, Menus, ExtCtrls, ComCtrls, Dialogs, ShellApi,
  Img32, Img32.Layers, Img32.Draw, Img32.Text, Img32.Panels;

type

  //----------------------------------------------------------------------
  // A couple of custom layer classes ...
  //----------------------------------------------------------------------

  TMyVectorLayer32 = class(TVectorLayer32) //for vector drawn layers
  private
    BrushColor : TColor32;
    PenColor   : TColor32;
    PenWidth   : double;
    FrameWidth : integer;
    IsRectangle: Boolean;
    textPath   : TPathsD;
    textRect   : TRect;
  protected
    procedure Draw; override;
  public
    constructor Create(parent: TLayer32;  const name: string = ''); override;
    procedure SetBounds(const newBounds: TRect); override;
  end;

  //----------------------------------------------------------------------
  //----------------------------------------------------------------------

  TMainForm = class(TForm)
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Exit1: TMenuItem;
    StatusBar1: TStatusBar;
    PopupMenu1: TPopupMenu;
    mnuDeleteLayer: TMenuItem;
    AddEllipse1: TMenuItem;
    AddRectangle1: TMenuItem;
    Action1: TMenuItem;
    mnuAddRectangle: TMenuItem;
    mnuAddEllipse: TMenuItem;
    N5: TMenuItem;
    mnuDeleteLayer2: TMenuItem;
    N1: TMenuItem;
    N2: TMenuItem;
    mnuSendBack: TMenuItem;
    mnuBringForward: TMenuItem;
    procedure mnuExitClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure pnlMainMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pnlMainMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure pnlMainMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure mnuBringToFrontClick(Sender: TObject);
    procedure mnuSendToBackClick(Sender: TObject);
    procedure mnuDeleteLayerClick(Sender: TObject);
    procedure PopupMenu1Popup(Sender: TObject);
    procedure mnuAddEllipseClick(Sender: TObject);
    procedure mnuAddRectangleClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormPaint(Sender: TObject);
    procedure mnuSendBackClick(Sender: TObject);
    procedure mnuBringForwardClick(Sender: TObject);
    procedure WMERASEBKGND(var message: TMessage); message WM_ERASEBKGND;
  private
    layeredImg32: TLayeredImage32;
    clickedLayer: TLayer32;
    targetLayer: TMyVectorLayer32;
    buttonGroup   : TGroupLayer32;
    clickPoint    : TPoint;
    function MakeRandomRect: TRect;
    procedure SetTargetLayer(layer: TMyVectorLayer32);
  public
  end;

var
  MainForm: TMainForm;
  glyphs: TGlyphCache;


implementation

{$R *.dfm}

uses
  Img32.Fmt.BMP, Img32.Fmt.PNG, Img32.Fmt.JPG, Img32.Fmt.SVG,
  Img32.Vector, Img32.Extra, Img32.Clipper;

//------------------------------------------------------------------------------
// TMyVectorLayer32
//------------------------------------------------------------------------------

constructor TMyVectorLayer32.Create(parent: TLayer32; const name: string = '');
var
  hsl: THsl;
begin
  inherited;
  hsl.hue := Random(256);
  hsl.sat := 240;
  hsl.lum := 200;
  hsl.Alpha := 192;
  BrushColor := HslToRgb(hsl);
  hsl.lum := 60;
  Margin := 0;
  PenColor := HslToRgb(hsl);
  PenWidth := DpiAware(5);
  FrameWidth := DpiAware(15);
  IsRectangle := name = 'rectangle';

  textPath := glyphs.GetTextGlyphs(0,0,name);
  textRect := Img32.Vector.GetBounds(textPath);
  textPath := OffsetPath(textPath, -textRect.Left, -textRect.Top);
  types.OffsetRect(textRect,-textRect.Left, -textRect.Top);
end;
//------------------------------------------------------------------------------

procedure TMyVectorLayer32.SetBounds(const newBounds: TRect);
var
  pp: TPathsD;
  rec: TRect;
begin
  inherited;
  //nb: ClipPath is relative to the Layer
  rec := Image.Bounds;
  if IsRectangle then
  begin
    Img32.Vector.InflateRect(rec, -FrameWidth, -FrameWidth);
    ClipPath := Img32.Vector.Paths(Rectangle(rec));
  end else
  begin
    pp := Img32.Vector.Paths(Ellipse(rec));
    UpdateHitTestMask(pp, frEvenOdd);

    //the more perfect way to do this would be to use
    //InflatePath but that way is *much* slower
    Img32.Vector.InflateRect(rec, -FrameWidth, -FrameWidth);
    ClipPath := Img32.Vector.Paths(Ellipse(rec));
  end;
end;
//------------------------------------------------------------------------------

procedure DrawFrame(img: TImage32; const rec: TRect;
  topLeftColor, bottomRightColor: TColor32; penWidth: double = 1.0);
var
  p: TPathD;
begin
  if topLeftColor <> bottomRightColor then
  begin
    with rec do
    begin
      p := MakePathD([left, bottom, left, top, right, top]);
      DrawLine(img, p, penWidth, topLeftColor, esButt);
      p := MakePathD([right, top, right, bottom, left, bottom]);
      DrawLine(img, p, penWidth, bottomRightColor, esButt);
    end;
  end else
    DrawLine(img, Rectangle(rec), penWidth, topLeftColor, esPolygon);
end;
//------------------------------------------------------------------------------

procedure DrawEllipseFrame(img: TImage32; const rec: TRect;
  topLeftColor, bottomRightColor: TColor32; penWidth: double = 1.0);
var
  p: TPathD;
  cLtr,cDkr: TColor32;
begin
  if topLeftColor <> bottomRightColor then
  begin
    cLtr := GradientColor(topLeftColor, bottomRightColor, 0.33);
    cDkr := GradientColor(topLeftColor, bottomRightColor, 0.67);
    with rec do
    begin
      p := Arc(RectD(rec),angle150,-angle60);
      DrawLine(img, p, penWidth, topLeftColor, esButt);
      p := Arc(RectD(rec), -angle60, -angle45);
      DrawLine(img, p, penWidth, cLtr, esButt);
      p := Arc(RectD(rec), -angle45, -angle30);
      DrawLine(img, p, penWidth, cDkr, esButt);
      p := Arc(RectD(rec),-angle30, angle120);
      DrawLine(img, p, penWidth, bottomRightColor, esButt);
      p := Arc(RectD(rec),angle120,angle135);
      DrawLine(img, p, penWidth, cDkr, esButt);
      p := Arc(RectD(rec),angle135,angle150);
      DrawLine(img, p, penWidth, cLtr, esButt);
    end;
  end else
    DrawLine(img, Ellipse(rec), penWidth, topLeftColor, esPolygon);
end;
//------------------------------------------------------------------------------

procedure TMyVectorLayer32.Draw;
var
  i, fw: integer;
  pp: TPathsD;
  rec: TRect;
  delta: TPointD;
begin
  rec := Image.Bounds;
  //prepare to center text
  delta.X := (RectWidth(rec) - RectWidth(textRect)) div 2;
  delta.Y := (RectHeight(rec) - RectHeight(textRect)) div 2;

  if IsRectangle then
  begin
    fw := FrameWidth - dpiAwareI;
    Image.Clear(rec, MakeLighter(BrushColor, 70));
    i := Ceil(DpiAwareD/2);
    img32.Vector.InflateRect(rec, -i, -i);
    DrawFrame(Image, rec, clWhite32, $FFCCCCCC, dpiAwareI);
    img32.Vector.InflateRect(rec, -fw, -fw);
    Image.Clear(rec, BrushColor);
    DrawFrame(Image, rec, $FFCCCCCC, clWhite32);
  end else
  begin
    fw := FrameWidth - dpiAwareI;
    DrawPolygon(Image, Ellipse(rec), frNonZero, MakeLighter(BrushColor, 70));
    i := Ceil(DpiAwareD/2);
    img32.Vector.InflateRect(rec, -i,-i);
    DrawEllipseFrame(Image, rec, clWhite32, $FFCCCCCC, dpiAwareI);
    img32.Vector.InflateRect(rec, -fw, -fw);
    DrawPolygon(Image, Ellipse(rec), frNonZero, BrushColor);
    DrawEllipseFrame(Image, rec, $FFCCCCCC, clWhite32);
  end;

  //draw the text
  pp := OffsetPath(textPath, delta.X, delta.Y);
  DrawPolygon(Image, pp, frNonZero, clBlack32);
end;

//------------------------------------------------------------------------------
// TMainForm methods
//------------------------------------------------------------------------------

procedure TMainForm.FormCreate(Sender: TObject);
var
  fr: TFontReader;
begin
  Randomize;

  self.OnMouseDown := pnlMainMouseDown;
  self.OnMouseMove := pnlMainMouseMove;
  self.OnMouseUp := pnlMainMouseUp;
  self.PopupMenu := PopupMenu1;
  self.OnKeyDown := FormKeyDown;

  layeredImg32 := TLayeredImage32.Create; //sized in FormResize below.

  //prepare for a hatched background design layer (see FormResize below).
  layeredImg32.AddLayer(TDesignerLayer32);

  fr := FontManager.Load('Arial');
  glyphs := TGlyphCache.Create(fr, DPIAware(12));
end;
//------------------------------------------------------------------------------

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(layeredImg32); //see also FormResize
  glyphs.free;
end;
//------------------------------------------------------------------------------

procedure TMainForm.WMERASEBKGND(var message: TMessage);
begin
  message.Result := 0;
end;
//------------------------------------------------------------------------------

procedure TMainForm.FormResize(Sender: TObject);
var
  rec: TRect;
  w,h: integer;
begin
  if not Assigned(layeredImg32) then Exit; //ie when destroying

  rec := ClientRect;
  w := RectWidth(rec);
  h := RectHeight(rec);
  //resize pnlMain's Image
  //resize layeredImg32 to pnlMain
  layeredImg32.SetSize(w, h);
  //resize and repaint the hatched design background layer
  with TDesignerLayer32(layeredImg32[0]) do
  begin
    //nb: use SetSize not Resize which would waste
    //CPU cycles stretching any previous hatching
    SetSize(w,h);
    HatchBackground(Image);
  end;
  invalidate; //force repaint (ie even when resizing smaller)
end;
//------------------------------------------------------------------------------

function TMainForm.MakeRandomRect: TRect;
begin
  if Assigned(targetLayer) then
  begin
    Result.Left := Random(targetLayer.Width);
    Result.Top := Random(targetLayer.Height);
    Result.Right := Random(targetLayer.Width);
    Result.Bottom := Random(targetLayer.Height);
  end else
  begin
    Result.Left := Random(layeredImg32.Width);
    Result.Top := Random(layeredImg32.Height);
    Result.Right := Random(layeredImg32.Width);
    Result.Bottom := Random(layeredImg32.Height);
  end;
  Img32.Vector.NormalizeRect(Result);
  if Result.Right - Result.Left < 75 then
    Result.Right := Result.Left +75;
  if Result.Bottom - Result.Top < 50 then
    Result.Bottom := Result.Top +50;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuAddEllipseClick(Sender: TObject);
var
  newLayer: TMyVectorLayer32;
  rec: TRect;
begin
  rec := MakeRandomRect;
  newLayer := layeredImg32.AddLayer(
    TMyVectorLayer32, targetLayer, 'ellipse') as TMyVectorLayer32;
  //setting a path will automatically define the layer's bounds
  newLayer.Paths := Img32.Vector.Paths(Ellipse(rec));
  SetTargetLayer(newLayer);
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuAddRectangleClick(Sender: TObject);
var
  newLayer: TMyVectorLayer32;
  rec: TRect;
begin
  rec := MakeRandomRect;
  newLayer := layeredImg32.AddLayer(
    TMyVectorLayer32, targetLayer, 'rectangle') as TMyVectorLayer32;
  newLayer.SetBounds(rec);
  //a path isn't required for rectangular paths
  //since that's the default when no path is specified
  //newLayer.Paths := Img32.Vector.Paths(Rectangle(rec));
  SetTargetLayer(newLayer);
end;
//------------------------------------------------------------------------------

procedure TMainForm.FormPaint(Sender: TObject);
var
  updateRect: TRect;
  img: TImage32;
begin
  img := layeredImg32.GetMergedImage(false, updateRect);
  //only update 'updateRect' otherwise repainting can be quite slow
  if not IsEmptyRect(updateRect) then
    img.CopyToDc(updateRect, updateRect, canvas.Handle);
end;
//------------------------------------------------------------------------------

procedure TMainForm.FormKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and Assigned(targetLayer) then
  begin
    SetTargetLayer(nil); //deselect the active control
    Key := 0;
  end;
end;
//------------------------------------------------------------------------------

procedure TMainForm.SetTargetLayer(layer: TMyVectorLayer32);
begin
  if targetLayer = layer then Exit;
  FreeAndNil(buttonGroup);
  targetLayer := layer;
  //add sizing buttons around the target layer
  if assigned(targetLayer) then
    buttonGroup := CreateSizingButtonGroup(layer,
      ssCorners, bsRound, DPIAware(10), clGreen32);
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.pnlMainMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  clickPoint := Types.Point(X,Y);
  clickedLayer := layeredImg32.GetLayerAt(clickPoint);

  if Assigned(clickedLayer) then
  begin
    if (clickedLayer = targetLayer) or not
      (clickedLayer is TMyVectorLayer32) then Exit;
    SetTargetLayer(clickedLayer as TMyVectorLayer32);
    Invalidate;
  end else if assigned(targetLayer) then
  begin
    FreeAndNil(buttonGroup);
    targetLayer := nil;
    Invalidate;
  end;
end;
//------------------------------------------------------------------------------

procedure TMainForm.pnlMainMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  dx, dy: integer;
  pt: TPoint;
  layer: TLayer32;
  rec: TRect;
begin
  pt := Types.Point(X,Y);

  if not (ssLeft in Shift) then
  begin
    //not moving anything so just update the cursor
    layer := layeredImg32.GetLayerAt(pt);
    if Assigned(layer) then
      self.Cursor := layer.CursorId else
      self.Cursor := crDefault;
    Exit;
  end;

  if not Assigned(clickedLayer) then Exit; //we're not moving anything :)

  dx := pt.X - clickPoint.X;
  dy := pt.Y - clickPoint.Y;
  clickPoint := pt;

  if clickedLayer is TButtonDesignerLayer32 then
  begin
    //we're moving a sizing button of the target
    clickedLayer.Offset(dx, dy);
    //call UpdateSizingButtonGroup to reposition the other buttons
    //in the sizing group and get the bounds rect for the target layer
    rec := UpdateSizingButtonGroup(clickedLayer);
    //convert rec from layeredImg32 coordinates to targetLayer coords
    pt := targetLayer.MergedImagePtToLayerPt(NullPoint);
    types.OffsetRect(rec, pt.X, pt.Y);

    targetLayer.SetBounds(rec);
    Invalidate;
  end
  else if Assigned(targetLayer) then
  begin
    //we're moving the target itself
    targetLayer.Offset(dx, dy);
    if assigned(buttonGroup) then buttonGroup.Offset(dx, dy);
    Invalidate;
  end;
end;
//------------------------------------------------------------------------------

procedure TMainForm.pnlMainMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  clickedLayer := nil;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuExitClick(Sender: TObject);
begin
  Close;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuBringToFrontClick(Sender: TObject);
begin
  if not assigned(targetLayer) then Exit;

  //don't send above the (top-most) sizing button group
  if targetLayer.Index = targetLayer.Parent.ChildCount -2 then Exit;

  if targetLayer.BringForwardOne then
    Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuSendToBackClick(Sender: TObject);
begin
  //don't send below the (bottom-most) hatched background.
  if targetLayer.Index = 1 then Exit;

  if targetLayer.SendBackOne then
    Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuDeleteLayerClick(Sender: TObject);
begin
  if not assigned(targetLayer) then Exit;
  FreeAndNil(targetLayer);
  FreeAndNil(buttonGroup);
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.PopupMenu1Popup(Sender: TObject);
begin
  mnuDeleteLayer.Enabled := assigned(targetLayer);
  mnuDeleteLayer2.Enabled := mnuDeleteLayer.Enabled;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuSendBackClick(Sender: TObject);
begin
  if Assigned(targetLayer) then
    targetLayer.SendBackOne;
  Invalidate;
end;
//------------------------------------------------------------------------------

procedure TMainForm.mnuBringForwardClick(Sender: TObject);
begin
  if Assigned(targetLayer) then
    targetLayer.BringForwardOne;
  Invalidate;
end;
//------------------------------------------------------------------------------


end.