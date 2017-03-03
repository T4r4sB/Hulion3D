unit Sounds;

interface

uses
  MMSystem;

procedure Sound(Nota: byte);
procedure DeSound(Nota: byte);
procedure NoSound;
procedure SetStyle(Style: byte);
procedure SetVolume(aVolume: byte);
procedure SetChanel(aChanel: byte);
procedure InitSounds;
procedure CloseSounds;

const Instruments: array [0 .. 127] of string=(
  'AcousticGrandPiano', 'BrightAcousticPiano', 'ElectricGrandPiano',
  'HonkyTonkPiano', 'ElectricPiano1', 'ElectricPiano2',
  'Harpsichord', 'Clavinet', 'Celesta', 'Glockenspiel',
  'MusicBox', 'Vibraphone', 'Marimba', 'Xylophone',
  'TubularBells', 'Dulcimer', 'DrawbarOrgan', 'PercussiveOrgan',
  'RockOrgan', 'ChurchOrgan', 'ReedOrgan', 'Accordion', 'Harmonica',
  'TangoAccordion', 'AcousticNylonGuitar', ' AcousticSteelGuitar',
  'JazzElectricGuitar', 'CleanElectricGuitar', 'MutedElectricGuitar',
  'OverdrivenGuitar', 'DistortionGuitar', 'GuitarHarmonics',
  'AcousticBass', 'FingeredElectricBass', 'PickedElectricBass',
  'FretlessBass', 'SlapBass1', 'SlapBass2', 'SynthBass1',
  'SynthBass2', 'Violin', 'Viola', 'Cello', 'Contrabass',
  'TremoloStrings', 'PizzicatoStrings', 'OrchestralHarp',
  'Timpani', 'StringEnsemble1', 'StringEnsemble2', 'SynthStrings1',
  'SynthStrings2', 'ChoirAahs', 'VoiceOohs', 'SynthVoice',
  'OrchestraHit', 'Trumpet', 'Trombone', 'Tuba', 'MutedTrumpet',
  'FrenchHorn', 'BrassSection', 'SynthBrass1', 'SynthBrass2',
  'SopranoSax', 'AltoSax', 'TenorSax', 'BaritoneSax', 'Oboe',
  'EnglishHorn', 'Bassoon', 'Clarinet', 'Piccolo', 'Flute',
  'Recorder', 'PanFlute', 'BlownBottle', 'Shakuhachi', 'Whistle',
  'Ocarina', 'SquareLead', 'SawtoothLead', 'CalliopeLead',
  'ChiffLead', 'CharangLead', 'VoiceLead', 'FifthsLead',
  'BassandLead', 'NewAgePad', 'WarmPad', 'PolySynthPad',
  'ChoirPad', 'BowedPad', 'MetallicPad', 'HaloPad', 'SweepPad',
  'SynthFXRain', 'SynthFXSoundtrack', 'SynthFXCrystal',
  'SynthFXAtmosphere', 'SynthFXBrightness', 'SynthFXGoblins',
  'SynthFXEchoes', 'SynthFXSciFi', 'Sitar', 'Banjo', 'Shamisen',
  'Koto', 'Kalimba', 'Bagpipe', 'Fiddle', 'Shanai', 'TinkleBell',
  'Agogo', 'SteelDrums', 'Woodblock', 'TaikoDrum', 'MelodicTom',
  'SynthDrum', 'ReverseCymbal', 'GuitarFretNoise', 'BreathNoise',
  'Seashore', 'BirdTweet', 'TelephoneRing', 'Helicopter',
  'Applause', 'Gunshot');

implementation

var
  hmidi: integer;
  Volume: array [0 .. 15] of byte;
  Chanel: byte;
  IsSound: array [0 .. 15] of boolean;

procedure Sound(Nota: byte);
begin
  MidiOutShortMsg(hMidi, $90 or Chanel or Nota shl 8 or Volume[Chanel] shl 16);
end;

procedure DeSound(Nota: byte);
begin
  MidiOutShortMsg(hMidi, $90 or Chanel or Nota shl 8);
end;

procedure NoSound;
var
  aNota: byte;
begin
 for aNota := 0 to 127 do
    MidiOutShortMsg(hMidi, $90 or Chanel or aNota shl 8);
end;

procedure SetStyle(Style: byte);
begin                                    
  MidiOutShortMsg(hmidi, Style shl 8 or $C0 or Chanel);
end;

procedure SetVolume(aVolume: byte);
begin
  Volume[Chanel] := AVolume;
end;

procedure SetChanel(aChanel: byte);
begin
  Chanel := AChanel;
end;

procedure InitSounds;
var
  i: integer;
  uDevID : integer;
begin
  uDevID := -1;
  MidiOutOpen(@hmidi,cardinal(uDevID),0,0,0);

  Chanel := 0;
  Volume[Chanel] := $7F;
  for i := 0 to 15 do
    IsSound[i] := False;
end;

procedure CloseSounds;
begin
  MidiOutClose(hmidi);
end;

initialization
finalization
end.
