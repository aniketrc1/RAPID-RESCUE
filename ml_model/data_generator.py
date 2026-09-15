import os
import numpy as np
import pandas as pd
import random

# Ensure directories
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(BASE_DIR, 'data', 'raw')
os.makedirs(RAW_DIR, exist_ok=True)

# ── Simulation Parameters ───────────────────────────────────────────────────
HZ = 100  # 100 Hz sampling rate
GRAVITY = 9.81

def generate_noise(length, ax_std=0.5, ay_std=0.5, az_std=0.5, rx_std=0.1, ry_std=0.1, rz_std=0.1):
    return {
        'ax': np.random.normal(0, ax_std, length),
        'ay': np.random.normal(0, ay_std, length),
        'az': np.random.normal(0, az_std, length),
        'rx': np.random.normal(0, rx_std, length),
        'ry': np.random.normal(0, ry_std, length),
        'rz': np.random.normal(0, rz_std, length)
    }

def create_base_df(duration_sec):
    length = int(duration_sec * HZ)
    times = np.linspace(0, duration_sec, length)
    noise = generate_noise(length)
    df = pd.DataFrame({
        'Time (s)': times,
        'Acceleration x (m/s^2)': noise['ax'],
        'Acceleration y (m/s^2)': noise['ay'] + GRAVITY, # Gravity
        'Acceleration z (m/s^2)': noise['az'],
        'Gyroscope x (rad/s)': noise['rx'],
        'Gyroscope y (rad/s)': noise['ry'],
        'Gyroscope z (rad/s)': noise['rz']
    })
    return df

# ────────────────────────────────────────────────────────────────────────────
# ── MOTORCYCLE SCENARIOS ────────────────────────────────────────────────────
# ────────────────────────────────────────────────────────────────────────────

def generate_moto_normal(duration=60):
    df = create_base_df(duration)
    length = len(df)
    turn_events = random.randint(2, 5)
    for _ in range(turn_events):
        start = random.randint(0, length - int(5 * HZ))
        end = start + int(random.uniform(2, 5) * HZ)
        turn_intensity = random.uniform(-0.5, 0.5)
        df.loc[start:end, 'Gyroscope z (rad/s)'] += np.sin(np.linspace(0, np.pi, end-start+1)) * turn_intensity
        df.loc[start:end, 'Acceleration x (m/s^2)'] += np.sin(np.linspace(0, np.pi, end-start+1)) * (turn_intensity * 2)
    return df

def generate_moto_hard_brake(duration=30):
    df = create_base_df(duration)
    length = len(df)
    brake_start = random.randint(int(10 * HZ), length - int(5 * HZ))
    brake_end = brake_start + int(random.uniform(1.5, 3.0) * HZ)
    df.loc[brake_start:brake_end, 'Acceleration z (m/s^2)'] -= np.sin(np.linspace(0, np.pi, brake_end-brake_start+1)) * random.uniform(5.0, 9.0)
    df.loc[brake_start:brake_end, 'Gyroscope x (rad/s)'] += np.sin(np.linspace(0, np.pi, brake_end-brake_start+1)) * random.uniform(0.5, 1.5)
    return df

def generate_moto_low_side(duration=30):
    df = create_base_df(duration)
    length = len(df)
    crash_start = int(random.uniform(15, 25) * HZ)
    impact_duration = int(0.5 * HZ)
    slide_duration = int(3.0 * HZ)
    
    df.loc[crash_start:crash_start+impact_duration, 'Gyroscope z (rad/s)'] += random.uniform(3.0, 7.0)
    direction = random.choice([-1, 1])
    impact_g = random.uniform(50, 150)
    df.loc[crash_start:crash_start+5, 'Acceleration x (m/s^2)'] += impact_g * direction
    df.loc[crash_start:crash_start+5, 'Acceleration y (m/s^2)'] += random.uniform(30, 80)
    
    slide_end = crash_start + impact_duration + slide_duration
    df.loc[crash_start+5:slide_end, 'Acceleration x (m/s^2)'] += np.random.normal(0, 15, slide_end - (crash_start+5))
    df.loc[crash_start+5:slide_end, 'Gyroscope x (rad/s)'] += np.random.normal(0, 5, slide_end - (crash_start+5))
    
    df.loc[slide_end:, 'Acceleration y (m/s^2)'] = np.random.normal(0, 0.2, length - slide_end)
    df.loc[slide_end:, 'Acceleration x (m/s^2)'] = np.random.normal(GRAVITY * direction, 0.2, length - slide_end)
    df.loc[slide_end:, 'Gyroscope z (rad/s)'] = np.random.normal(0, 0.05, length - slide_end)
    return df

def generate_moto_high_side(duration=30):
    df = create_base_df(duration)
    length = len(df)
    crash_start = int(random.uniform(15, 25) * HZ)
    flip_duration = int(0.6 * HZ)
    
    df.loc[crash_start:crash_start+flip_duration, 'Gyroscope x (rad/s)'] += random.uniform(10.0, 20.0)
    df.loc[crash_start:crash_start+flip_duration, 'Gyroscope z (rad/s)'] += random.uniform(5.0, 15.0)
    
    df.loc[crash_start+flip_duration:crash_start+flip_duration+10, 'Acceleration x (m/s^2)'] += random.uniform(100, 200) * random.choice([-1, 1])
    df.loc[crash_start+flip_duration:crash_start+flip_duration+10, 'Acceleration y (m/s^2)'] += random.uniform(100, 250)
    df.loc[crash_start+flip_duration:crash_start+flip_duration+10, 'Acceleration z (m/s^2)'] += random.uniform(80, 150)
    
    rest_start = crash_start + flip_duration + int(1.0 * HZ)
    df.loc[rest_start:, 'Acceleration y (m/s^2)'] = np.random.normal(random.uniform(-9.81, 9.81), 0.1, length - rest_start)
    df.loc[rest_start:, 'Acceleration x (m/s^2)'] = np.random.normal(random.uniform(-9.81, 9.81), 0.1, length - rest_start)
    df.loc[rest_start:, 'Acceleration z (m/s^2)'] = np.random.normal(random.uniform(-9.81, 9.81), 0.1, length - rest_start)
    return df

# ────────────────────────────────────────────────────────────────────────────
# ── CAR SCENARIOS (Less rotation, higher impact mass constraint) ────────────
# ────────────────────────────────────────────────────────────────────────────

def generate_car_normal(duration=60):
    df = create_base_df(duration)
    length = len(df)
    # Cars don't lean. Just lateral Gs on turns, forward/back Gs on accel/brake.
    turn_events = random.randint(2, 5)
    for _ in range(turn_events):
        start = random.randint(0, length - int(5 * HZ))
        end = start + int(random.uniform(2, 5) * HZ)
        turn_g = random.uniform(1.0, 4.0) * random.choice([-1, 1])
        df.loc[start:end, 'Acceleration x (m/s^2)'] += np.sin(np.linspace(0, np.pi, end-start+1)) * turn_g
        df.loc[start:end, 'Gyroscope y (rad/s)'] += np.sin(np.linspace(0, np.pi, end-start+1)) * (turn_g * 0.1) # sligth yaw
    return df

def generate_car_hard_brake(duration=30):
    df = create_base_df(duration)
    length = len(df)
    brake_start = random.randint(int(10 * HZ), length - int(5 * HZ))
    brake_end = brake_start + int(random.uniform(1.5, 4.0) * HZ)
    
    # Car braking can hit -1g (-9.81 m/s^2)
    df.loc[brake_start:brake_end, 'Acceleration z (m/s^2)'] -= np.sin(np.linspace(0, np.pi, brake_end-brake_start+1)) * random.uniform(8.0, 12.0)
    # Very minor pitch (nose dive)
    df.loc[brake_start:brake_end, 'Gyroscope x (rad/s)'] += np.sin(np.linspace(0, np.pi, brake_end-brake_start+1)) * random.uniform(0.1, 0.4)
    return df

def generate_car_head_on(duration=30):
    df = create_base_df(duration)
    length = len(df)
    crash_start = int(random.uniform(15, 25) * HZ)
    
    # Massive Z decel spike in very short time (~50-100ms)
    impact_frames = int(0.1 * HZ)
    df.loc[crash_start:crash_start+impact_frames, 'Acceleration z (m/s^2)'] -= random.uniform(200, 500) # 20g-50g
    df.loc[crash_start:crash_start+impact_frames, 'Acceleration y (m/s^2)'] += random.uniform(50, 150)  # sudden vertical jolt
    
    # Violent pitch (dashboard hits knees, back end flies up)
    df.loc[crash_start:crash_start+impact_frames, 'Gyroscope x (rad/s)'] += random.uniform(4.0, 10.0)
    
    # Dead stop
    rest_start = crash_start + impact_frames + int(0.5 * HZ)
    df.loc[rest_start:, 'Acceleration z (m/s^2)'] = np.random.normal(0, 0.1, length - rest_start)
    return df

def generate_car_side_impact(duration=30):
    df = create_base_df(duration)
    length = len(df)
    crash_start = int(random.uniform(15, 25) * HZ)
    
    impact_frames = int(0.12 * HZ) # T-bone
    direction = random.choice([-1, 1])
    
    # Massive lateral acceleration
    df.loc[crash_start:crash_start+impact_frames, 'Acceleration x (m/s^2)'] += random.uniform(150, 400) * direction
    # Violent roll & yaw
    df.loc[crash_start:crash_start+impact_frames, 'Gyroscope z (rad/s)'] += random.uniform(3.0, 8.0) * direction
    df.loc[crash_start:crash_start+impact_frames, 'Gyroscope y (rad/s)'] += random.uniform(5.0, 12.0) * direction
    
    return df

def generate_car_rear_end(duration=30):
    df = create_base_df(duration)
    length = len(df)
    crash_start = int(random.uniform(15, 25) * HZ)
    
    # Hit from behind -> massive forward acceleration
    impact_frames = int(0.15 * HZ)
    df.loc[crash_start:crash_start+impact_frames, 'Acceleration z (m/s^2)'] += random.uniform(100, 300)
    # Head snaps backward (pitch negative)
    df.loc[crash_start:crash_start+impact_frames, 'Gyroscope x (rad/s)'] -= random.uniform(3.0, 7.0)
    
    return df


# ── Generation Loop ─────────────────────────────────────────────────────────

def main():
    print("Generating synthetic dataset (Cars & Motorcycles)...")
    
    # Clear old synthetic data
    for f in os.listdir(RAW_DIR):
        if f.startswith('syn_'):
            os.remove(os.path.join(RAW_DIR, f))
            
    counts = {
        # Motorcycles
        "moto_normal": 40, "moto_hardbrake": 30, "moto_lowside": 40, "moto_highside": 40, "moto_rearend": 20,
        # Cars
        "car_normal": 40, "car_hardbrake": 30, "car_headon": 40, "car_side": 40, "car_rearend": 30
    }
    
    total = sum(counts.values())
    curr = 0
    
    for c_type, count in counts.items():
        for i in range(count):
            if c_type == "moto_normal":
                df = generate_moto_normal(random.uniform(40, 80))
            elif c_type == "moto_hardbrake":
                df = generate_moto_hard_brake(random.uniform(30, 60))
            elif c_type == "moto_lowside":
                df = generate_moto_low_side(random.uniform(30, 40))
            elif c_type == "moto_highside":
                df = generate_moto_high_side(random.uniform(30, 40))
            elif c_type == "moto_rearend":
                # Fallback to car rear end just for simplicity or create a specific one
                df = generate_car_rear_end(random.uniform(30, 40))
            elif c_type == "car_normal":
                df = generate_car_normal(random.uniform(40, 80))
            elif c_type == "car_hardbrake":
                df = generate_car_hard_brake(random.uniform(30, 60))
            elif c_type == "car_headon":
                df = generate_car_head_on(random.uniform(30, 40))
            elif c_type == "car_side":
                df = generate_car_side_impact(random.uniform(30, 40))
            elif c_type == "car_rearend":
                df = generate_car_rear_end(random.uniform(30, 40))
            else:
                df = generate_moto_normal(30) # fallback
                
            filename = f"syn_{c_type}_{i+1:03d}.csv"
            df.to_csv(os.path.join(RAW_DIR, filename), index=False)
            curr += 1
            if curr % 50 == 0:
                print(f"  Generated {curr}/{total} files...")
                
    print(f"✅ Finished generating {total} synthetic files in {RAW_DIR}")

if __name__ == '__main__':
    main()
