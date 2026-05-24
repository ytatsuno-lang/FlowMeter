// 流量計算式 (iOS版 Model.swift と完全互換)

// メーター式: 1周容量[L] × 3.6 / 経過秒 = m³/h
// 例: 100L / 36秒 → 10.0 m³/h
export function flowRateMeter(capacityL, seconds) {
  if (!(seconds > 0)) return 0;
  return capacityL * 3.6 / seconds;
}

// 水槽の断面積 [m²]
export function tankCrossSection(tank) {
  if (tank.shape === 'rectangular') {
    return (tank.width || 0) * (tank.depth || 0);
  }
  // circular
  const r = (tank.diameter || 0) / 2;
  return Math.PI * r * r;
}

// 体積変化 [m³]
export function tankVolumeM3(tank) {
  return Math.abs(tankCrossSection(tank) * (tank.levelDelta || 0));
}

// 水槽式流量 [m³/h]
export function flowRateTank(tank) {
  const sec = tank.elapsedSeconds || 0;
  if (!(sec > 0)) return 0;
  return tankVolumeM3(tank) * 3600 / sec;
}

// 計測の平均流量を返す（メーター/水槽どちらにも対応）
export function averageFlowRate(measurement) {
  if (measurement.method === 'tank') {
    return measurement.tank ? flowRateTank(measurement.tank) : null;
  }
  // meter
  const laps = measurement.lapTimes || [];
  if (laps.length === 0) return null;
  const avg = laps.reduce((a, b) => a + b, 0) / laps.length;
  return flowRateMeter(measurement.capacityL, avg);
}

// 水槽の寸法ラベル
export function tankDimensionsLabel(tank) {
  if (tank.shape === 'rectangular') {
    return `${(tank.width ?? 0).toFixed(2)} × ${(tank.depth ?? 0).toFixed(2)} m`;
  }
  return `Φ${(tank.diameter ?? 0).toFixed(2)} m`;
}
