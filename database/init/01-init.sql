-- MeshRelay Database Schema
-- Initialize database for user management and service configuration

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table - stores registered users and their devices
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP
);

-- Meshtastic devices registered to users
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    node_id BIGINT NOT NULL, -- Meshtastic node ID
    node_id_hex VARCHAR(8) NOT NULL, -- Hex representation of node ID
    device_name VARCHAR(255),
    region VARCHAR(10), -- e.g., 'ANZ', 'US', 'EU_868'
    last_seen TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    UNIQUE(node_id)
);

-- Available destination services
CREATE TABLE services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    mqtt_host VARCHAR(255),
    mqtt_port INTEGER DEFAULT 1883,
    mqtt_username VARCHAR(255),
    mqtt_password_encrypted TEXT,
    service_type VARCHAR(50), -- 'mapping', 'environmental', 'custom'
    is_active BOOLEAN DEFAULT true,
    requires_auth BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User service preferences - which services each user wants to use
CREATE TABLE user_service_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    service_id UUID REFERENCES services(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT true,
    message_filters JSONB, -- Store filtering rules as JSON
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, service_id)
);

-- Message relay logs - track what messages were sent where
CREATE TABLE relay_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
    service_id UUID REFERENCES services(id) ON DELETE CASCADE,
    topic VARCHAR(255) NOT NULL,
    message_type VARCHAR(50), -- 'POSITION', 'TELEMETRY', 'ENVIRONMENTAL', etc.
    relayed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    success BOOLEAN DEFAULT true,
    error_message TEXT
);

-- Service health monitoring
CREATE TABLE service_health (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_id UUID REFERENCES services(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'unknown', -- 'healthy', 'degraded', 'down', 'unknown'
    last_check TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    response_time_ms INTEGER,
    error_count INTEGER DEFAULT 0,
    last_error TEXT
);

-- Insert default services
INSERT INTO services (name, description, mqtt_host, mqtt_port, service_type, is_active) VALUES
    ('WeSense Environmental Network', 'Community-driven environmental monitoring network', 'mqtt.wesense.earth', 1883, 'environmental', true),
    ('Meshtastic Map', 'Original Meshtastic mapping service by Liam Cottle', 'mqtt.meshtastic.liamcottle.net', 1883, 'mapping', true),
    ('MeshMap.net', 'Community Meshtastic mapping service', 'mqtt.meshmap.net', 1883, 'mapping', false);

-- Create indexes for performance
CREATE INDEX idx_devices_user_id ON devices(user_id);
CREATE INDEX idx_devices_node_id ON devices(node_id);
CREATE INDEX idx_devices_last_seen ON devices(last_seen);
CREATE INDEX idx_user_service_preferences_user_id ON user_service_preferences(user_id);
CREATE INDEX idx_relay_logs_device_id ON relay_logs(device_id);
CREATE INDEX idx_relay_logs_service_id ON relay_logs(service_id);
CREATE INDEX idx_relay_logs_relayed_at ON relay_logs(relayed_at);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_devices_updated_at BEFORE UPDATE ON devices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_service_preferences_updated_at BEFORE UPDATE ON user_service_preferences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
