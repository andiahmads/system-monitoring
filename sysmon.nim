import nimraylib_now as rl
import os, strformat, strutils, sequtils, osproc


 # Warna modern
const
  COLORS = [
    rl.Color(r: 0, g: 191, b: 255, a: 255),
    rl.Color(r: 255, g: 105, b: 180, a: 255),
    rl.Color(r: 138, g: 43, b: 226, a: 255),
    rl.Color(r: 152, g: 245, b: 255, a: 255)
  ]

when isMainModule:
  echo COLORS[0]  # Prints first color


proc getCpuInfo(): string =
  # Cross-platform CPU info fetcher
  when defined(macosx):
    try:
      result = execProcess("sysctl -n machdep.cpu.brand_string").strip()
    except:
      result = "Apple CPU"
  elif defined(linux):
    try:
      let cpuinfo = readFile("/proc/cpuinfo")
      for line in cpuinfo.splitLines():
        if line.startsWith("model name"):
          return line.split(":")[1].strip()
      result = "Unknown Linux CPU"
    except:
      result = "Unknown CPU"
  else:
    result = "Unknown Platform"


type
  SystemStats = object
    cpuUsage: float
    memUsed: float
    memTotal: float
    processes: int

when defined(macosx):
  proc getMacMemInfo(): (float,float) =
    let
      totalMem = execProcess("sysctl -n hw.memsize").strip().parseBiggestInt() / 1024 / 1024

      # hitung memory bebas dari vm_stat
      vmStat = execProcess("vm_stat").splitLines()
      pageSize = execProcess("pagesize").strip().parseFloat() # 1024/1024

    var freeMem = 0.0
    for line in vmStat:
      if line.contains("Pages free"):
        freeMem += line.split(":")[1].strip().split(".")[0].strip().parseFloat() * pageSize
      elif line.contains("page inactive"):
        freeMem += line.split(":")[1].strip().split(".")[0].strip().parseFloat() * pageSize

    (totalMem-freeMem,totalMem)


proc getStats(): SystemStats =
  # Mendapatkan statistik systems (cross-platform)
  when defined(macosx):
    # macOS: Pakai sysctl, vm_stat, dan top
    let (memUsed, memTotal) = getMacMemInfo()
    let cpuLine = execProcess("top -l 1 -n 0 | grep 'CPU usage'").strip()
    let cpuUsed = cpuLine.split("CPU usage: ")[1].split("%")[0].strip().parseFloat()
    
    SystemStats(
      cpuUsage: cpuUsed,
      memUsed: memUsed,
      memTotal: memTotal,
      processes: execProcess("ps -A").countLines() - 1
    )


proc drawGauge(posX,posY:int, value,maxValue: float, label:string,color:rl.Color) =
# gambar gauge meter
  const
    width = 300
    height = 30
  let
    fillWidth = (value / maxValue * width.float).int

   # background
  rl.drawRectangle(posX, posY, width, height, rl.fade(rl.GRAY, 0.3))
  # fill
  rl.drawRectangle(posX,posY,fillWidth,height,color)
  # border
  rl.drawRectangleLines(posX,posY,width,height,rl.WHITE)
  # text
  rl.drawText(
    &"{label}: {value.formatFloat(ffDecimal, 1)} / {maxValue.formatFloat(ffDecimal, 1)}",
    posX + width + 10, posY + 5, 20, rl.WHITE)


proc drawCpuHistoryGraph(posX, posY: int, history: openArray[float], color: rl.Color) =
  const
    graphWidth = 760
    graphHeight = 120
    padding = 20
  
  # Draw graph background
  rl.drawRectangle(posX, posY, graphWidth, graphHeight, rl.fade(rl.BLACK, 0.3))
  rl.drawRectangleLines(posX, posY, graphWidth, graphHeight, rl.fade(rl.WHITE, 0.5))
  
  # Draw grid lines
  for i in 0..10:
    let y = posY + graphHeight - (i * (graphHeight div 10))
    rl.drawLine(posX, y, posX + graphWidth, y, rl.fade(rl.WHITE, 0.1))
    rl.drawText($(i*10), posX - 25, y - 10, 15, rl.fade(rl.WHITE, 0.5))
  
  # Draw graph
  if history.len > 1:
    var points: seq[rl.Vector2]
    for i, val in history.pairs:
      let
        x = posX + (i.float / history.high.float * (graphWidth - padding*2).float).int + padding
        y = posY + graphHeight - (val / 100 * graphHeight.float).int
      points.add(rl.Vector2(x: x.float, y: y.float))
    
    # Draw smooth line
    for i in 0..<points.high:
      rl.drawLineBezier(
        points[i],
        points[i+1],
        2.0,
        color
      )
    
    # Draw current value indicator
    let lastVal = history[^1]
    rl.drawText(
      &"{lastVal.formatFloat(ffDecimal, 1)}%",
      posX + graphWidth - 60,
      posY + 10,
      20,
      color
    )

    # Draw min/max labels
    let
      maxVal = max(history)
      minVal = min(history)
    rl.drawText(
      &"Max: {maxVal.formatFloat(ffDecimal, 1)}%",
      posX + graphWidth - 150,
      posY + 35,
      15,
      color
    )
    rl.drawText(
      &"Min: {minVal.formatFloat(ffDecimal, 1)}%",
      posX + graphWidth - 150,
      posY + 55,
      15,
      color
    )




proc drawHistoryGraph(posX, posY: int, history: openArray[float], color: rl.Color, title: string, unit: string) =
  const
    graphWidth = 760
    graphHeight = 120
    padding = 20
  
  # Graph Background
  rl.drawRectangle(posX, posY, graphWidth, graphHeight, rl.fade(rl.BLACK, 0.3))
  rl.drawRectangleLines(posX, posY, graphWidth, graphHeight, rl.fade(rl.WHITE, 0.5))

  # Auto-Scaling
  let maxValue = max(history.max, 1.0)  # Avoid division by zero

  # Grid and Labels
  for i in 0..10:
    let
      y = posY + graphHeight - (i * (graphHeight div 10))
      value = (i * maxValue.toInt() / 10).formatFloat(ffDecimal, 1)
    rl.drawLine(posX, y, posX + graphWidth, y, rl.fade(rl.WHITE, 0.1))
    rl.drawText(value & unit, posX - 40, y - 10, 15, rl.fade(rl.WHITE, 0.5))

  # Smooth Graph Line
  if history.len > 1:
    var points: seq[rl.Vector2]
    for i, val in history.pairs:
      points.add(rl.Vector2(
        x: posX.float + padding + (i.float / history.high.float * (graphWidth - padding*2)),
        y: posY.float + graphHeight - (val / maxValue * graphHeight.float)
      ))
    
    for i in 0..<points.high:
      rl.drawLineBezier(points[i], points[i+1], 2.0, color)
    
    # Current Value Indicator
    rl.drawRectangleRounded(
      rl.Rectangle(
        x: posX.float + graphWidth - 80,
        y: posY.float + 5,
        width: 75,
        height: 25
      ), 0.3, 5, rl.fade(rl.BLACK, 0.5)
    )
    rl.drawText(
      history[^1].formatFloat(ffDecimal, 1) & unit,
      posX + graphWidth - 75,
      posY + 10,
      20,
      rl.WHITE
    )

  # Title
  rl.drawText(title, posX + 10, posY - 25, 20, color)

proc main =
  rl.initWindow(800, 600, "Nim System Monitor (Linux/macOS)")
  rl.setTargetFPS(60)

  var
    stats: SystemStats
    cpuHistory: array[100,float]
    memHistory:array[100,float]
    historyIndex = 0

  while not rl.windowShouldClose():
    stats = getStats()
    cpuHistory[historyIndex] = stats.cpuUsage
    memHistory[historyIndex] = stats.memUsed
    historyIndex = (historyIndex+1) mod cpuHistory.len

    let cpuInfo = getCpuInfo()

    # begin drawing
    rl.beginDrawing()
    rl.clearBackground(rl.BLACK) # dark background

    # header
    rl.drawText("NIM SYSTEM MONITORING",20,10,40,COLORS[3])  
    let osName = when defined(macosx): "macOS" else: "Linux"
    rl.drawText(&"OS: {osName} | CPU: {cpuInfo}", 20, 60, 20, COLORS[3])

    # CPU usage
    drawGauge(20,120,stats.cpuUsage,100.0, "CPU usage",rl.RED)

     # Process Counter
    rl.drawText(&"Running Processes: {stats.processes}", 20, 220, 20, COLORS[2])
    

    drawHistoryGraph(20, 220, cpuHistory, COLORS[0], "CPU Usage History", "%")
    
    # Memory History Graph
    drawHistoryGraph(20, 370, memHistory, COLORS[1], "Memory Usage History", " MB")

    
    rl.endDrawing()
  
  rl.closeWindow()





when isMainModule:
  main()

