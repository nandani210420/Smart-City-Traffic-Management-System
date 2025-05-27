-- Drop and recreate schema
DROP SCHEMA IF EXISTS smart_city CASCADE;
CREATE SCHEMA IF NOT EXISTS smart_city;

-- Vehicles Table
CREATE TABLE smart_city.vehicles (
    vehicle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plate_number VARCHAR(15) UNIQUE NOT NULL,
    owner_name VARCHAR(100),
    vehicle_type VARCHAR(20) CHECK (vehicle_type IN ('Car', 'Truck', 'Bike', 'Bus')),
    registration_date DATE DEFAULT CURRENT_DATE
);

-- Traffic Sensors Table
CREATE TABLE smart_city.traffic_sensors (
    sensor_id SERIAL PRIMARY KEY,
    location VARCHAR(100) NOT NULL,
    installed_on DATE NOT NULL,
    status BOOLEAN DEFAULT TRUE
);

-- Sensor Logs Table
CREATE TABLE smart_city.sensor_logs (
    log_id SERIAL PRIMARY KEY,
    sensor_id INT REFERENCES smart_city.traffic_sensors(sensor_id),
    vehicle_count INT NOT NULL,
    avg_speed DECIMAL(5,2),
    log_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Cameras Table
CREATE TABLE smart_city.cameras (
    camera_id SERIAL PRIMARY KEY,
    location VARCHAR(100),
    installed_on DATE,
    status BOOLEAN DEFAULT TRUE
);

-- Traffic Lights Table
CREATE TABLE smart_city.traffic_lights (
    light_id SERIAL PRIMARY KEY,
    junction_name VARCHAR(50),
    mode VARCHAR(20) CHECK (mode IN ('Auto', 'Manual')),
    cycle_time INT CHECK (cycle_time > 0),
    schedule JSONB, -- e.g., {"Mon-Fri": {"07:00-10:00": "fast"}, "Sat": {...}}
    status BOOLEAN DEFAULT TRUE
);

-- Violations Table
CREATE TABLE smart_city.violations (
    violation_id SERIAL PRIMARY KEY,
    vehicle_id UUID REFERENCES smart_city.vehicles(vehicle_id),
    camera_id INT REFERENCES smart_city.cameras(camera_id),
    type VARCHAR(30) CHECK (type IN ('Signal Jump', 'Speeding', 'Wrong Lane')),
    fine_amount DECIMAL(10,2),
    violation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Alerts Table
CREATE TABLE smart_city.alerts (
    alert_id SERIAL PRIMARY KEY,
    location VARCHAR(100),
    alert_type VARCHAR(30) CHECK (alert_type IN ('Congestion', 'Accident', 'Sensor Fail')),
    severity VARCHAR(10) CHECK (severity IN ('Low', 'Medium', 'High')),
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- View: Real-time congestion view
CREATE OR REPLACE VIEW smart_city.congestion_view AS
SELECT 
    ts.location, 
    sl.log_timestamp, 
    sl.vehicle_count, 
    sl.avg_speed
FROM 
    smart_city.sensor_logs sl
JOIN 
    smart_city.traffic_sensors ts 
    ON sl.sensor_id = ts.sensor_id
WHERE 
    sl.vehicle_count > 50 OR sl.avg_speed < 10;

-- Trigger Function for Speeding Fine
CREATE OR REPLACE FUNCTION auto_fine_speeding()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.type = 'Speeding' THEN
    NEW.fine_amount := 200.00;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger on Violations Insert
CREATE TRIGGER trg_fine_speeding
BEFORE INSERT ON smart_city.violations
FOR EACH ROW
EXECUTE FUNCTION auto_fine_speeding();

-- Indexes for Performance
CREATE INDEX idx_sensor_logs_timestamp ON smart_city.sensor_logs(log_timestamp);
CREATE INDEX idx_violations_type ON smart_city.violations(type);
CREATE INDEX idx_vehicles_plate ON smart_city.vehicles(plate_number);
