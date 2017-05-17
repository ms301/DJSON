{***************************************************************************}
{                                                                           }
{           DJSON - (Delphi JSON library)                                   }
{                                                                           }
{           Copyright (C) 2016 Maurizio Del Magno                           }
{                                                                           }
{           mauriziodm@levantesw.it                                         }
{           mauriziodelmagno@gmail.com                                      }
{           https://github.com/mauriziodm/DSON.git                          }
{                                                                           }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  This file is part of DJSON (Delphi JSON library).                        }
{                                                                           }
{  Licensed under the GNU Lesser General Public License, Version 3;         }
{  you may not use this file except in compliance with the License.         }
{                                                                           }
{  DJSON is free software: you can redistribute it and/or modify            }
{  it under the terms of the GNU Lesser General Public License as published }
{  by the Free Software Foundation, either version 3 of the License, or     }
{  (at your option) any later version.                                      }
{                                                                           }
{  DJSON is distributed in the hope that it will be useful,                 }
{  but WITHOUT ANY WARRANTY; without even the implied warranty of           }
{  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            }
{  GNU Lesser General Public License for more details.                      }
{                                                                           }
{  You should have received a copy of the GNU Lesser General Public License }
{  along with DJSON.  If not, see <http://www.gnu.org/licenses/>.           }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  This project is based off of the ObjectsMappers unit included with the   }
{  Delphi MVC Framework project by Daniele Teti and the DMVCFramework Team. }
{                                                                           }
{***************************************************************************}





unit DJSON.Utils.RTTI;

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo;

type

  TdjRTTI = class sealed
  private
    class var TValueToStringFormatSettings: TFormatSettings;
    class procedure Initialize; static;
  public
    class var Ctx: TRttiContext;
    class function TValueToObject(const AValue: TValue): TObject; static;
    class function TypeInfoToTypeName(const ATypeInfo: PTypeInfo; const AQualified:Boolean=False): String; static;
    class function TypeInfoToRttiType(const ATypeInfo: PTypeInfo): TRttiType; static;
    class function QualifiedTypeNameToRttiType(const AQualifiedTypeName:String): TRttiType; static;
    class function CreateObject(ARttiType: TRttiType): TObject; overload; static;
    class function CreateObject(AQualifiedClassName: string): TObject; overload; static;
    class function HasAttribute<T: class>(const ARTTIMember: TRttiNamedObject): boolean; overload;
    class function HasAttribute<T: class>(const ARTTIMember: TRttiNamedObject; out AAttribute: T): boolean; overload; static;
    class function GetItemsQualifiedTypeNameFromArrayTypeInfo(const ATypeInfo:PTypeInfo): String; static;
  end;

implementation

uses
  DJSON.Exceptions;

class function TdjRTTI.CreateObject(ARttiType: TRttiType): TObject;
var
  Method: TRttiMethod;
  metaClass: TClass;
begin
  { First solution, clear and slow }
  metaClass := nil;
  Method := nil;
  for Method in ARttiType.GetMethods do
    if Method.HasExtendedInfo and Method.IsConstructor then
      if Length(Method.GetParameters) = 0 then
      begin
        metaClass := ARttiType.AsInstance.MetaclassType;
        Break;
      end;
  if Assigned(metaClass) then
    Result := Method.Invoke(metaClass, []).AsObject
  else
    raise Exception.Create('Cannot find a propert constructor for ' +
      ARttiType.ToString);

  { Second solution, dirty and fast }
  // Result := TObject(ARttiType.GetMethod('Create')
  // .Invoke(ARttiType.AsInstance.MetaclassType, []).AsObject);
end;

class function TdjRTTI.CreateObject(AQualifiedClassName: string): TObject;
var
  rttitype: TRttiType;
begin
  rttitype := ctx.FindType(AQualifiedClassName);
  if Assigned(rttitype) then
    Result := CreateObject(rttitype)
  else
    raise Exception.Create('Cannot find RTTI for ' + AQualifiedClassName);
end;

class function TdjRTTI.GetItemsQualifiedTypeNameFromArrayTypeInfo(
  const ATypeInfo: PTypeInfo): String;
var
  LType: TRttiType;
begin
  // Get RttiType
  LType := Ctx.GetType(ATypeInfo);
  // If it is a dynamic or static array...
  if LType is TRttiDynamicArrayType then
    Result := TRttiDynamicArrayType(LType).ElementType.QualifiedName
  else if LType is TRttiArrayType then
    Result := TRttiArrayType(LType).ElementType.QualifiedName
  else
    raise EdjException.Create('TdjRTTI.GetItemsQualifiedTypeNameFromArrayTypeInfo: It is not an array.');
end;

class procedure TdjRTTI.Initialize;
begin
  Ctx := TRttiContext.Create;
  Ctx.FindType(''); // Workaround for thread safe: https://quality.embarcadero.com/browse/RSP-9815
end;

class function TdjRTTI.TValueToObject(const AValue: TValue): TObject;
begin
  Result := nil;
  case AValue.TypeInfo.Kind of
    tkInterface: Result := AValue.AsInterface As TObject;
    tkClass: Result := AValue.AsObject;
    else
      raise Exception.Create('TRTTIUtils.TValueToObject: The TValue does not contain an object or interfaced object.');
  end;
end;

class function TdjRTTI.TypeInfoToTypeName(const ATypeInfo: PTypeInfo; const AQualified:Boolean): String;
begin
// From XE7
{$IFDEF NEXTGEN}
  // Get the type name
  Result := ATypeInfo.NameFld.ToString;
  // If a qualifiedname is required...
  if AQualified then
  begin
    // If it is an interface then link the Interface unit to the TypeName
    if  ATypeInfo.Kind = tkInterface then
      Result := ATypeInfo.TypeData.IntfUnitFld.ToString + '.' + Result
    // else (class) link the class unit to the TypeName
    else
      Result := ATypeInfo.TypeData.UnitNameFld.ToString + '.' + Result;
  end;
// Before XE7
{$ELSE  NEXTGEN}
  Result := ATypeInfo.Name;
{$ENDIF NEXTGEN}
end;

class function TdjRTTI.TypeInfoToRttiType(
  const ATypeInfo: PTypeInfo): TRttiType;
begin
  Result := nil;
  Result := Ctx.GetType(ATypeInfo);
end;

class function TdjRTTI.HasAttribute<T>(
  const ARTTIMember: TRttiNamedObject): boolean;
var
  AAttribute: TCustomAttribute;
begin
  Result := HasAttribute<T>(ARTTIMember, AAttribute);
end;

class function TdjRTTI.HasAttribute<T>(const ARTTIMember: TRttiNamedObject;
  out AAttribute: T): boolean;
var
  attrs: TArray<TCustomAttribute>;
  attr: TCustomAttribute;
begin
  if not Assigned(ARTTIMember) then
    Exit(False);
  AAttribute := nil;
  Result := false;
  attrs := ARTTIMember.GetAttributes;
  for attr in attrs do
    if attr is T then
    begin
      AAttribute := T(attr);
      Exit(True);
    end;
end;

class function TdjRTTI.QualifiedTypeNameToRttiType(
  const AQualifiedTypeName: String): TRttiType;
begin
  Result := nil;
  Result := Ctx.FindType(AQualifiedTypeName);
end;

initialization

  TdjRTTI.Initialize;

end.
