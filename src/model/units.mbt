///|
/// Physical quantity represented by a SPEF unit declaration.
pub(all) enum Quantity {
  Time
  Capacitance
  Resistance
  Inductance
} derive(Eq, Debug)

///|
/// Unit declaration normalized to an SI multiplier.
pub(all) struct UnitScale {
  quantity : Quantity
  magnitude : Double
  symbol : String
  multiplier : Double
} derive(Eq, Debug)

///|
pub fn UnitScale::new(
  quantity : Quantity,
  magnitude : Double,
  symbol : String,
) -> UnitScale? {
  match unit_multiplier(quantity, symbol) {
    Some(base) =>
      Some({ quantity, magnitude, symbol, multiplier: magnitude * base })
    None => None
  }
}

///|
pub fn UnitScale::to_si(self : UnitScale, value : Double) -> Double {
  value * self.multiplier
}

///|
pub fn default_time_unit() -> UnitScale {
  UnitScale::new(Time, 1.0, "NS").unwrap()
}

///|
pub fn default_capacitance_unit() -> UnitScale {
  UnitScale::new(Capacitance, 1.0, "PF").unwrap()
}

///|
pub fn default_resistance_unit() -> UnitScale {
  UnitScale::new(Resistance, 1.0, "OHM").unwrap()
}

///|
pub fn default_inductance_unit() -> UnitScale {
  UnitScale::new(Inductance, 1.0, "HENRY").unwrap()
}

///|
fn unit_multiplier(quantity : Quantity, symbol : String) -> Double? {
  match (quantity, symbol) {
    (Time, "S") => Some(1.0)
    (Time, "MS") => Some(1.0e-3)
    (Time, "US") => Some(1.0e-6)
    (Time, "NS") => Some(1.0e-9)
    (Time, "PS") => Some(1.0e-12)
    (Time, "FS") => Some(1.0e-15)
    (Capacitance, "F") => Some(1.0)
    (Capacitance, "MF") => Some(1.0e-3)
    (Capacitance, "UF") => Some(1.0e-6)
    (Capacitance, "NF") => Some(1.0e-9)
    (Capacitance, "PF") => Some(1.0e-12)
    (Capacitance, "FF") => Some(1.0e-15)
    (Resistance, "OHM") => Some(1.0)
    (Resistance, "KOHM") => Some(1.0e3)
    (Resistance, "MOHM") => Some(1.0e6)
    (Inductance, "HENRY") => Some(1.0)
    (Inductance, "MH") => Some(1.0e-3)
    (Inductance, "UH") => Some(1.0e-6)
    (Inductance, "NH") => Some(1.0e-9)
    (Inductance, "PH") => Some(1.0e-12)
    _ => None
  }
}
