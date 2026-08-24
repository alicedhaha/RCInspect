///|
pub(all) struct AstHeader {
  keyword : String
  values : Array[String]
  span : @diagnostic.SourceSpan
} derive(Debug)

///|
pub(all) struct AstNameMapEntry {
  index : Int
  name : String
  span : @diagnostic.SourceSpan
} derive(Debug)

///|
pub(all) struct AstPort {
  name : String
  direction : String
  coordinate : (Double, Double)?
  span : @diagnostic.SourceSpan
} derive(Debug)

///|
pub(all) struct AstConnection {
  kind : String
  name : String
  direction : String
  coordinate : (Double, Double)?
  load : Double?
  driving_cell : String?
  span : @diagnostic.SourceSpan
} derive(Debug)

///|
pub(all) struct AstCapacitor {
  id : Int
  first : String
  second : String?
  value : Double
  span : @diagnostic.SourceSpan
} derive(Debug)

///|
pub(all) struct AstResistor {
  id : Int
  first : String
  second : String
  value : Double
  span : @diagnostic.SourceSpan
} derive(Debug)

///|
pub(all) struct AstNet {
  name : String
  declared_capacitance : Double
  connections : Array[AstConnection]
  capacitors : Array[AstCapacitor]
  resistors : Array[AstResistor]
  span : @diagnostic.SourceSpan
} derive(Debug)

///|
pub(all) struct SpefAst {
  headers : Array[AstHeader]
  name_map : Array[AstNameMapEntry]
  ports : Array[AstPort]
  nets : Array[AstNet]
} derive(Debug)

///|
pub(all) struct ParseResult {
  ast : SpefAst
  network : @model.RCNetwork
  diagnostics : Array[@diagnostic.Diagnostic]
} derive(Debug)
