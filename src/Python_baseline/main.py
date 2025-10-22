import random
import time

def simulate(L, N, T):
    particles = []
    for n in range(N):
        particles.append([random.randint(0, L-1), random.randint(0, L-1)])

    central = 0
    for t in range(T):
        for p in particles:
            direction = random.choice(((0,1), (0,-1), (1,0), (-1,0)))
            p[0] = (p[0] + direction[0]) % L
            p[1] = (p[1] + direction[1]) % L
    
        for p in particles:
            if L * 0.25 <= p[0] < L * 0.75 and L * 0.25 <= p[1] < L * 0.75:
                central += 1
    return central / (N * T)

if __name__ == '__main__':
    L = 512
    N = 100000
    T = 1000
    start_time = time.monotonic()
    ratio = simulate(L, N, T)
    print(f"Average dwell ratio: {ratio:.4f}")
    print(f"Simulation time: {time.monotonic() - start_time:.6f}s")