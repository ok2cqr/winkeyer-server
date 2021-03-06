unit uCWKeying;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, synaser, synautil, lNetComponents;

type TKeyType   = (ktCWdaemon, ktWinKeyer);
type TKeyStatus = (ksReady, ksBusy);
  
type

  TCWKeying = class
    ser : TBlockSerial;
    udp : TLUDPComponent;

    function  wk_open : Boolean;
    function  wk_get_speed : Word;
    function  wk_get_status : TKeyStatus;
    
    procedure wk_close;
    procedure wk_send_text(text : String);
    procedure wk_stop_sending;
    procedure wk_set_speed(wpm : Word);
    procedure wk_del_last_char;
    procedure wk_set_min_max_speed(min,max : Word);
    /////////////////////////////////////////////////////////
    
    function  cw_open : Boolean;
    
    procedure cw_close;
    procedure cw_send_text(text : String);
    procedure cw_stop_sending;
    procedure cw_set_speed(wpm : Word);
    
  private
    fActive    : Boolean;
    fKeyType   : TKeyType;
    fPort      : String;
    fLastErrNr : Word;
    fLastErrSt : String;
    fSpeed     : Word;
    fDevice    : String;
    fDebugMode : Boolean;
    fMinSpeed  : Word;
    fMaxSpeed  : Word;
    fFirmware  : String;

  public
    property Active    : Boolean read fActive;
    property KeyType   : TKeyType read fKeyType write fKeyType;
    property Port      : String read fPort write fPort;
    property Device    : String read fDevice write fDevice;
    property LastErrNr : Word read fLastErrNr;
    property LastErrSt : String read fLastErrSt;
    property DebugMode : Boolean read fDebugMode write fDebugMode;
    property MinSpeed  : Word read fMinSpeed;
    property MaxSpeed  : Word read fMaxSpeed;
    property Firmware  : String read fFirmware;
    constructor Create;
    destructor  Destroy; override;
    
    function GetSpeed  : Word;
    function GetStatus : TKeyStatus;
    
    procedure Open;
    procedure Close;
    procedure SetSpeed(speed : Word);
    procedure SendText(text : String);
    procedure StopSending;
    procedure DelLastChar;
    procedure SetMixManSpeed(min,max : Word);
  end;

implementation

constructor TCWKeying.Create;
begin
  fActive       := False;
  fKeyType      := ktWinKeyer;
  fDebugMode    := False;
  ser           := TBlockserial.Create;
  ser.LinuxLock := False;
  udp           := TLUDPComponent.Create(nil);
  fMinSpeed     := 5;
  fMaxSpeed     := 60;
  fFirmware     := ''
end;

destructor TCWKeying.Destroy;
begin
  inherited;
  if fActive then
    Close;
  ser.Free
end;

procedure TCWKeying.Open;
begin
  if fActive then
    Close;
  if fKeyType = ktWinKeyer then
  begin
    if wk_open then
      fActive := True
  end
  else begin
    if cw_open then
      fActive := True
  end;
end;

procedure TCWKeying.Close;
begin
  if fActive then
  begin
    if fKeyType = ktWinKeyer then
      wk_close
    else
      cw_close;
    fActive := False
  end
end;

function TCWKeying.GetSpeed : Word;
begin
  Result := fSpeed
end;

function TCWKeying.GetStatus : TKeyStatus;
begin
  Result := ksBusy
end;

procedure TCWKeying.SetSpeed(speed : Word);
begin
  if fKeyType =  ktWinKeyer then
    wk_set_speed(speed)
  else
    cw_set_speed(speed);
  fSpeed := speed
end;

procedure TCWKeying.SendText(text : String);
begin
  if not fActive then
    exit;
  if fKeyType = ktWinKeyer then
    wk_send_text(text)
  else
    cw_send_text(text)
end;

procedure TCWKeying.StopSending;
begin
  if not fActive then
    exit;
  if fKeyType = ktWinKeyer then
    wk_stop_sending
  else
    cw_stop_sending
end;

procedure TCWKeying.DelLastChar;
begin
  if not fActive then
    exit;
  if fKeyType = ktWinKeyer then
    wk_del_last_char
end;

procedure TCWKeying.SetMixManSpeed(min,max : Word);
begin
  fMinSpeed := min;
  fMaxSpeed := max;
  if not fActive then
    exit;
  if fKeyType = ktWinKeyer then
    wk_set_min_max_speed(min,max)
end;

//---------------------------------------------------------------------

function TCWKeying.wk_open : Boolean;
var
  rec : byte;
begin
  if fDebugMode then Writeln('Device: ',fDevice);
  Result := False;
  ser.RaiseExcept := False;
  ser.Connect(fDevice);
  ser.Config(1200,8,'N',2,false,false);
  ser.DTR:=True;
  ser.RTS:=False;
  fLastErrNr := ser.LastError;
  fLastErrSt := ser.LastErrorDesc;
  if LastErrNr > 0 then
    exit;
  ser.SendByte(13);
  ser.SendByte(13);  //sending null commands
  ser.SendByte(13);
  sleep(50);
  if fDebugMode then Writeln('After sending null command');
  ser.SendByte(0);
  ser.SendByte(4);  //send echo command
  ser.SendByte(20);
  sleep(50);
  while ser.CanReadex(10) do
  begin
    rec := (ser.recvByte(0))
  end;
  if fDebugMode then Writeln('After sending echo command: ',rec);
  if rec = 20 then
    Result := True
  else begin
    fLastErrNr := 1000;
    fLastErrSt := 'WinKeyer USB inicialization failed';
    exit
  end;
  ser.SendByte(0);
  ser.SendByte(2); //enable communication
  sleep(50);
  while ser.CanReadex(10) do
  begin
    rec := (ser.recvByte(0))
  end;
  fFirmware := IntToStr(integer(rec));
  if fDebugMode then Writeln('Firmware version: ',rec);
  wk_set_speed(fSpeed)
end;

procedure TCWKeying.wk_close;
begin
  ser.SendByte(0);
  ser.SendByte(3); // close keyer
  if fDebugMode then Writeln('WinKeyer closed');
  ser.CloseSocket
end;

procedure TCWKeying.wk_send_text(text : String);
var
  i : Integer;
begin
  text := UpperCase(text);
  for i:=1 to Length(text) do
  begin
    if text[i] = '+' then
    begin
      fSpeed := fSpeed+5;
      ser.SendByte($1C);
      ser.SendByte(fSpeed);
      Continue
    end;
    if text[i] = '-' then
    begin
      fSpeed := fSpeed-5;
      ser.SendByte($1C);
      ser.SendByte(fSpeed);
      Continue
    end;
    case text[i] of
      '/' : begin
              ser.SendByte($1B);
              ser.SendString('D');
              ser.SendString('N')
            end;
      '?' : begin
              ser.SendByte($1B);
              ser.SendString('U');
              ser.SendString('D')
            end;
      '=' : begin
              ser.SendByte($1B);
              ser.SendString('B');
              ser.SendString('T')
            end;
      '.' : begin
              ser.SendByte($1B);
              ser.SendString('Z');
              ser.SendString('M')
            end;
      ':' : begin
              ser.SendByte($1B);
              ser.SendString('K');
              ser.SendString('N')
            end;
      ';' : begin
              ser.SendByte($1B);
              ser.SendString('A');
              ser.SendString('A')
            end;
      '<' : begin
              ser.SendByte($1B);
              ser.SendString('A');
              ser.SendString('R')
            end;
      '>' : begin
              ser.SendByte($1B);
              ser.SendString('S');
              ser.SendString('K')
            end;
      '(' : begin
              ser.SendByte($1B);
              ser.SendString('K');
              ser.SendString('N')
            end;
      ')' : begin
              ser.SendByte($1B);
              ser.SendString('K');
              ser.SendString('K')
            end;
      '@' : begin
              ser.SendByte($1B);
              ser.SendString('A');
              ser.SendString('C')
            end
      else
        Ser.SendString(text[i])
    end; //case
    if fDebugMode then Writeln('Sending text: ',text)
  end
end;

procedure TCWKeying.wk_stop_sending;
begin
  ser.SendByte($A)
end;

function TCWKeying.wk_get_speed : Word;
var
  rec : Byte;
begin
  ser.SendByte(7); //enable communication
  sleep(50);
  while ser.CanReadex(10) do
  begin
    rec := (ser.recvByte(0))
  end;
  Result := fMinSpeed + rec
end;

procedure TCWKeying.wk_set_speed(wpm : Word);
begin
  if fDebugMode then Writeln('Speed: ',wpm);
  ser.Flush;
  ser.SendByte(2);
  ser.SendByte(wpm);
  sleep(50)
end;

function TCWKeying.wk_get_status : TKeyStatus;
begin
  Result := ksBusy
end;

procedure TCWKeying.wk_del_last_char;
begin
  ser.SendByte($8)
end;

procedure TCWKeying.wk_set_min_max_speed(min,max : Word);
begin
  ser.SendByte(5);
  ser.SendByte(min);
  ser.SendByte(max)
end;

function TCWKeying.cw_open : Boolean;
begin
  if fDebugMode then
  begin
    Writeln('address: ',fDevice);
    Writeln('port:    ',fPort)
  end;
  udp.Host := fDevice;
  udp.Port := StrToInt(fPort);
  fActive  := udp.Connect;
  Result   := fActive;
  cw_set_speed(fSpeed)
end;

procedure TCWKeying.cw_close;
begin
  if udp.Connected then
    udp.Disconnect;
  fActive := False
end;

procedure TCWKeying.cw_send_text(text : String);
var
  i   : Integer;
  spd : Word;
  old_spd : Word = 0;
begin
  if not fActive then
    exit;

  text    := UpperCase(text);
  spd     := fSpeed;
  old_spd := spd;;
  text := UpperCase(text);
  if (Pos('+',text) > 0) or (Pos('-',text) > 0) then
  begin
    for i:=1 to Length(text) do
    begin
      if text[i] = '+' then
      begin
        spd := spd+5;
        udp.SendMessage(Chr(27)+'2'+IntToStr(spd))
      end
      else begin
        if text[i] = '-' then
        begin
          spd := spd-5;
          udp.SendMessage(Chr(27)+'2'+IntToStr(spd))
        end
        else
          udp.SendMessage(text[i])
      end
    end;
    udp.SendMessage(Chr(27)+'2'+IntToStr(old_spd))
  end
  else
    udp.SendMessage(text)
end;

procedure TCWKeying.cw_stop_sending;
begin
  if fActive then
    udp.SendMessage(Chr(27)+'4')
end;

procedure TCWKeying.cw_set_speed(wpm : Word);
begin
  if fActive then
    udp.SendMessage(Chr(27)+'2'+IntToStr(wpm))
end;



end.
