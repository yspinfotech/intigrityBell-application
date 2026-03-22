import wave, struct, math, os

out_dir = r"D:\Intigrity-Bell\intigrity\android\app\src\main\res\raw"
os.makedirs(out_dir, exist_ok=True)
file_path = os.path.join(out_dir, "alarm.wav")

sample_rate = 44100
duration = 3.0 # seconds
freq = 800.0 # Hz

file = wave.open(file_path, "w")
file.setnchannels(1)
file.setsampwidth(2)
file.setframerate(sample_rate)

for i in range(int(sample_rate * duration)):
    # Pulse 5 times a second
    envelope = 1 if math.sin(i * 2.0 * math.pi * 5.0 / sample_rate) > 0 else 0
    val = int(32767.0 * math.sin(2.0 * math.pi * freq * i / sample_rate)) * envelope
    data = struct.pack("<h", val)
    file.writeframesraw(data)

file.close()
print(f"Created {file_path}")
