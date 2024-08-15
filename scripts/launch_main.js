import { db, collection, getDocs } from "./firebase.js";
import config from "./config.js";

let dataPoints = [];
let records = [];
let hourlyData = {};
let dailyData = {};
let map;
let overlay;
let scatterplotLayer;
let pathLayer;
let animationFrameId;
const speed = 1;
let pathsData = [];
let isAnimating = false;

let selectedDataType = "temperature";
let selectedDisplayMode = "recordCount";

const gradientScales = {
  temperature: d3
    .scaleSequential(d3.interpolateRgb("dodgerblue", "crimson"))
    .domain([0, 40]),
  humidity: d3
    .scaleSequential(d3.interpolateRgb("lightblue", "darkblue"))
    .domain([0, 100]),
  pressure: d3
    .scaleSequential(d3.interpolateRgb("lightgreen", "darkgreen"))
    .domain([950, 1050]),
  gas: d3
    .scaleSequential(d3.interpolateRgb("brown", "yellow"))
    .domain([0, 500]),
  noise: d3
    .scaleSequential(d3.interpolateRgb("purple", "orange"))
    .domain([0, 100]),
  mvc: d3
    .scaleSequential(d3.interpolateRgb("lightgray", "black"))
    .domain([0, 10]),
  nmvc: d3.scaleSequential(d3.interpolateRgb("pink", "purple")).domain([0, 10]),
  pc: d3.scaleSequential(d3.interpolateRgb("cyan", "blue")).domain([0, 50]),
  sp: d3.scaleSequential(d3.interpolateRgb("white", "red")).domain([0, 100]),
  tp: d3.scaleSequential(d3.interpolateRgb("lime", "green")).domain([0, 100]),
};

async function fetchUserIDs() {
  const usersCollectionRef = collection(db, "users");
  const usersSnapshot = await getDocs(usersCollectionRef);
  const userIDs = usersSnapshot.docs.map((doc) => doc.id);
  return userIDs;
}

async function fetchUserRecords(userId) {
  const recordsCollectionRef = collection(db, `data/${userId}/records`);
  const recordsSnapshot = await getDocs(recordsCollectionRef);
  const userRecords = recordsSnapshot.docs.map((doc) => ({
    id: doc.id,
    data: doc.data(),
  }));
  return userRecords;
}

function getColorByValue(value, type) {
  const scale = gradientScales[type];
  if (scale) {
    const color = d3.color(scale(value));
    return [color.r, color.g, color.b, 100];
  }
  return [0, 0, 0, 100]; // Default color if no scale is found
}

function parseTime(time) {
  const [datePart, timePart] = time.split("_");
  const [year, month, day] = datePart
    .split("-")
    .map((part) => part.padStart(2, "0"));
  const [hours, minutes, seconds] = timePart
    .split(":")
    .map((part) => part.padStart(2, "0"));
  const dateTimeString = `${year}-${month}-${day}T${hours}:${minutes}:${seconds}`;
  const dateObject = new Date(dateTimeString);
  return dateObject;
}

async function displayAllUserRecords() {
  const userIDs = await fetchUserIDs();

  dataPoints = [];
  records = [];
  pathsData = [];
  hourlyData = {};
  dailyData = {};

  for (const userId of userIDs) {
    const userRecords = await fetchUserRecords(userId);

    userRecords.forEach((record) => {
      const { sensorData, endTime, startTime } = record.data;
      if (startTime && endTime) {
        const parsedStartTime = parseTime(startTime);
        const parsedEndTime = parseTime(endTime);
        records.push({
          startTime: parsedStartTime,
          endTime: parsedEndTime,
        });
      }

      if (sensorData) {
        const path = [];
        sensorData.forEach((dataPoint) => {
          const {
            phoneData,
            sensorData: innerSensorData,
            dlData,
            time,
          } = dataPoint;

          if (phoneData && phoneData.la && phoneData.lo) {
            const point = {
              position: [phoneData.lo, phoneData.la],
              noise: phoneData.no,
              temperature: innerSensorData?.t ?? 0,
              humidity: innerSensorData?.h ?? 0,
              pressure: innerSensorData?.p ?? 0,
              gas: innerSensorData?.g ?? 0,
              mvc: dlData?.mvc ?? 0,
              nmvc: dlData?.nmvc ?? 0,
              pc: dlData?.pc ?? 0,
              sp: dlData?.sp ?? 0,
              tp: dlData?.tp ?? 0,
            };
            point.color = getColorByValue(point.temperature, "temperature");
            dataPoints.push(point);
            path.push(point.position);

            const hour = parseTime(time).getHours();

            if (!hourlyData[hour]) {
              hourlyData[hour] = {
                noise: [],
                temperature: [],
                humidity: [],
                pressure: [],
                gas: [],
                mvc: [],
                nmvc: [],
                pc: [],
                sp: [],
                tp: [],
              };
            }
            hourlyData[hour].noise.push(point.noise);
            hourlyData[hour].temperature.push(point.temperature);
            hourlyData[hour].humidity.push(point.humidity);
            hourlyData[hour].pressure.push(point.pressure);
            hourlyData[hour].gas.push(point.gas);
            hourlyData[hour].mvc.push(point.mvc);
            hourlyData[hour].nmvc.push(point.nmvc);
            hourlyData[hour].pc.push(point.pc);
            hourlyData[hour].sp.push(point.sp);
            hourlyData[hour].tp.push(point.tp);

            const date = parseTime(time).getDate();
            const month = parseTime(time).getMonth();
            const dateId = `${month}-${date}`;
            if (!dailyData[dateId]) {
              dailyData[dateId] = {
                noise: [],
                temperature: [],
                humidity: [],
                pressure: [],
                gas: [],
                mvc: [],
                nmvc: [],
                pc: [],
                sp: [],
                tp: [],
              };
            }

            dailyData[dateId].noise.push(point.noise);
            dailyData[dateId].temperature.push(point.temperature);
            dailyData[dateId].humidity.push(point.humidity);
            dailyData[dateId].pressure.push(point.pressure);
            dailyData[dateId].gas.push(point.gas);
            dailyData[dateId].mvc.push(point.mvc);
            dailyData[dateId].nmvc.push(point.nmvc);
            dailyData[dateId].pc.push(point.pc);
            dailyData[dateId].sp.push(point.sp);
            dailyData[dateId].tp.push(point.tp);
          }
        });
        pathsData.push(path);
      }
    });
  }

  initializeMap(dataPoints, pathsData);
  createTimelineChart(
    records,
    hourlyData,
    dailyData,
    "temperature",
    "recordCount"
  );
}

displayAllUserRecords().catch((error) => {
  console.error("Error fetching user records: ", error);
});

function initializeMap(dataPoints, paths) {
  mapboxgl.accessToken = config.MAPBOX_ACCESS_TOKEN;
  map = new mapboxgl.Map({
    container: "map",
    style: "mapbox://styles/tianmingliu/clypw698q009p01qr4vwf5c17",
    center: [-0.13023371552561286, 51.51668299289028],
    zoom: 15,
    minZoom: 14.75,
    maxZoom: 17,
  });

  scatterplotLayer = new deck.ScatterplotLayer({
    id: "scatterplot-layer",
    data: dataPoints,
    stroked: true,
    getPosition: (d) => d.position,
    getFillColor: (d) => d.color,
    getRadius: (d) => 3,
    getLineWidth: 0.05,
    getLineColor: [255, 255, 255, 100],
  });

  pathLayer = new deck.PathLayer({
    id: "path-layer",
    data: paths.map((path) => ({ path: [] })),
    getPath: (d) => d.path,
    getColor: [255, 255, 255, 150],
    getWidth: 0.75,
    pickable: true,
    onClick: (info) => {
      if (info.object) {
        if (!isAnimating) {
          animateSinglePath(info.object.path, paths);
        }
      }
    },
  });

  overlay = new deck.MapboxOverlay({
    layers: [scatterplotLayer, pathLayer],
  });

  map.on("load", () => {
    map.addControl(overlay);
    map.addControl(new mapboxgl.NavigationControl());
    animatePaths(paths);
  });
}

function animatePaths(paths) {
  let currentIndex = 0;
  const maxIndex = Math.max(...paths.map((path) => path.length));
  isAnimating = true;

  function updatePaths() {
    const animatedPaths = paths.map((path) =>
      path.slice(0, Math.min(currentIndex, path.length))
    );

    overlay.setProps({
      layers: [
        scatterplotLayer,
        new deck.PathLayer({
          id: "path-layer",
          data: animatedPaths.map((path) => ({ path })),
          getPath: (d) => d.path,
          getColor: [255, 255, 255, 150],
          getWidth: 0.75,
          pickable: true,
          onClick: (info) => {
            if (info.object) {
              if (!isAnimating) {
                animateSinglePath(info.object.path, paths);
              }
            }
          },
        }),
      ],
    });

    if (currentIndex < maxIndex) {
      currentIndex += speed;
      animationFrameId = requestAnimationFrame(updatePaths);
    } else {
      cancelAnimationFrame(animationFrameId);
      isAnimating = false;
    }
  }

  animationFrameId = requestAnimationFrame(updatePaths);
}

function animateSinglePath(path, allPaths) {
  let currentIndex = 0;
  const maxIndex = path.length;
  isAnimating = true;

  const remainingPaths = allPaths
    .filter((p) => p !== path)
    .map((p) => ({ path: p }));
  overlay.setProps({
    layers: [
      scatterplotLayer,
      new deck.PathLayer({
        id: "remaining-path-layer",
        data: remainingPaths,
        getPath: (d) => d.path,
        getColor: [255, 255, 255, 150],
        getWidth: 0.75,
        pickable: true,
        onClick: (info) => {
          if (info.object) {
            if (!isAnimating) {
              animateSinglePath(info.object.path, allPaths);
            }
          }
        },
      }),
    ],
  });

  function updateSinglePath() {
    const animatedPath = path.slice(0, Math.min(currentIndex, path.length));

    overlay.setProps({
      layers: [
        scatterplotLayer,
        new deck.PathLayer({
          id: "remaining-path-layer",
          data: remainingPaths,
          getPath: (d) => d.path,
          getColor: [255, 255, 255, 150],
          getWidth: 0.75,
          pickable: true,
          onClick: (info) => {
            if (info.object) {
              if (!isAnimating) {
                animateSinglePath(info.object.path, allPaths);
              }
            }
          },
        }),
        new deck.PathLayer({
          id: "animated-path-layer",
          data: [{ path: animatedPath }],
          getPath: (d) => d.path,
          getColor: [255, 255, 255, 150],
          getWidth: 0.75,
          pickable: true,
          onClick: (info) => {
            if (info.object) {
              if (!isAnimating) {
                animateSinglePath(info.object.path, allPaths);
              }
            }
          },
        }),
      ],
    });

    if (currentIndex < maxIndex) {
      currentIndex += speed;
      animationFrameId = requestAnimationFrame(updateSinglePath);
    } else {
      cancelAnimationFrame(animationFrameId);
      isAnimating = false;
    }
  }

  currentIndex = 0;
  animationFrameId = requestAnimationFrame(updateSinglePath);
}

document.getElementById("displayMode").addEventListener("change", (event) => {
  selectedDisplayMode = event.target.value;
  console.log("Display mode changed:", displayMode);

  d3.select("#timeline").html("");
  createTimelineChart(
    records,
    hourlyData,
    dailyData,
    selectedDataType,
    selectedDisplayMode
  );
});

document.getElementById("dataControl").addEventListener("change", (event) => {
  selectedDataType = event.target.value;
  console.log("Data type control changed:", selectedDataType);

  dataPoints.forEach((point) => {
    point.color = getColorByValue(point[selectedDataType], selectedDataType);
  });

  overlay.setProps({
    layers: [],
  });

  overlay = new deck.MapboxOverlay({
    layers: [
      new deck.ScatterplotLayer({
        id: "scatterplot-layer",
        data: dataPoints,
        stroked: true,
        getPosition: (d) => d.position,
        getFillColor: (d) => d.color,
        getRadius: (d) => 3,
        getLineWidth: 0.05,
        getLineColor: [255, 255, 255, 100],
      }),
      new deck.PathLayer({
        id: "path-layer",
        data: pathsData.map((path) => ({ path: [] })),
        getPath: (d) => d.path,
        getColor: [255, 255, 255, 150],
        getWidth: 0.75,
        pickable: true,
        onClick: (info) => {
          if (info.object) {
            if (!isAnimating) {
              animateSinglePath(info.object.path, pathsData);
            }
          }
        },
      }),
    ],
  });

  map.addControl(overlay);
  console.log("Color control updated:", selectedDataType);

  d3.select("#timeline").html("");
  createTimelineChart(
    records,
    hourlyData,
    dailyData,
    selectedDataType,
    selectedDisplayMode
  );
});

function createTimelineChart(
  records,
  hourlyData,
  dailyData,
  dataType,
  displayMode
) {
  const timelineDiv = d3.select("#timeline");
  const margin = {
    top: 50,
    right: 20,
    bottom: 20,
    left: 100,
  };
  const totalWidth = document.getElementById("timeline").offsetWidth;
  console.log("totalWidth", totalWidth);
  console.log("margin", margin.left, margin.right);
  const width = (totalWidth - margin.left - margin.right) / 2;
  console.log("width", width);

  const unitSize = ((totalWidth - margin.left - margin.right) / 49) * 0.55;
  const cellSize = unitSize * 0.6; // Size of each cell
  const cellPadding = (unitSize - cellSize) / 2; // Padding between cells
  const height = unitSize * 7;

  const svg = timelineDiv
    .append("svg")
    .attr("width", totalWidth)
    .attr("height", height + margin.bottom)
    .append("g")
    .attr("transform", `translate(${margin.left},${margin.top})`);

  const x = d3.scaleLinear().domain([0, 24]).range([0, width]);

  let recordCounts = [];
  if (displayMode === "recordCount") {
    recordCounts = d3.range(24).map((hour) => {
      return records.filter((record) => record.startTime.getHours() === hour)
        .length;
    });
  } else if (displayMode === "averageValue") {
    recordCounts = d3.range(24).map((hour) => {
      const values =
        hourlyData[hour] && hourlyData[hour][dataType]
          ? hourlyData[hour][dataType]
          : [];
      return values.length ? d3.mean(values) : null;
    });
  }

  const colorScale =
    displayMode === "recordCount"
      ? d3
          .scaleSequential()
          .domain([0, d3.max(recordCounts)])
          .interpolator(
            d3.interpolateRgb("rgba(20, 20, 20,0.5)", "rgba(220, 220, 220,0.5)")
          )
      : gradientScales[dataType];

  const durationExtent = d3.extent(records, (record) => {
    const startTime =
      record.startTime.getHours() + record.startTime.getMinutes() / 60;
    const endTime =
      record.endTime.getHours() + record.endTime.getMinutes() / 60;
    return endTime - startTime;
  });

  const radiusScale = d3.scaleSqrt().domain(durationExtent).range([5, 15]);

  const hourGroup = svg.append("g").attr("transform", `translate(0, -20)`);
  // Add rectangles for each hour of the day, colored by the number of records
  // Add outer rectangles for the black border effect
  hourGroup
    .selectAll("outerRect")
    .data(recordCounts)
    .enter()
    .append("rect")
    .attr("x", (d, i) => x(i) + width)
    .attr("y", 0)
    .attr("width", width / 24)
    .attr("height", height * 0.8)
    .attr("fill", "none")
    .attr("stroke", "black")
    .attr("stroke-width", 2);

  // Add inner rectangles for the colored fill
  hourGroup
    .selectAll("innerRect")
    .data(recordCounts)
    .enter()
    .append("rect")
    .attr("x", (d, i) => x(i) + width)
    .attr("y", 0)
    .attr("width", width / 24 - 5)
    .attr("height", height * 0.8)
    .attr("fill", (d) => (d === null ? "black" : colorScale(d)))
    .attr("stroke", "white")
    .attr("stroke-width", 0.5)
    .attr("rx", 5)
    .attr("ry", 5);

  // Add text labels for each hour
  hourGroup
    .selectAll("hourLabel")
    .data(d3.range(24))
    .enter()
    .append("text")
    .attr("class", "hourLabel")
    .attr("x", (d) => x(d) + width + width / 96)
    .attr("y", -10)
    .style("fill", "white")
    .style("font-size", "8px")
    .text((d) => d);

  // add anotation for the time distribution
  const hourAnnotation = hourGroup
    .append("g")
    .attr("class", "annotation")
    .attr("transform", `translate(0, 0)`);
  hourAnnotation
    .append("text")
    .attr("x", width * 1.5)
    .attr("y", height * 0.9)
    .style("fill", "lightgrey")
    .style("font-size", "10px")
    .text("Daily Distribution");

  // Add Base line for the circle chart
  const baseLine = svg
    .append("line")
    .attr("x1", width)
    .attr("x2", width * 2)
    .attr("y1", height / 4)
    .attr("y2", height / 4)
    .attr("stroke", "lightgrey")
    .attr("stroke-width", 0.5);

  const circleGroup = svg.append("g").attr("transform", `translate(0, 0)`);

  records.forEach((record, index) => {
    const startTime =
      record.startTime.getHours() + record.startTime.getMinutes() / 60;
    const endTime =
      record.endTime.getHours() + record.endTime.getMinutes() / 60;
    const duration = endTime - startTime;
    const radius = radiusScale(duration);

    const startX = x(startTime);
    const endX = x(endTime);
    const cxValue = (startX + endX) / 2 + width;

    circleGroup
      .append("circle")
      .attr("cx", isNaN(cxValue) ? 0 : cxValue)
      .attr("cy", height / 4)
      .attr("r", radius)
      .attr("fill", "rgba(255, 255, 255, 0.75)")
      .attr("stroke", "black")
      .attr("stroke-width", 0.2);
  });

  // Create an array of all days in the year
  const allDays = d3.timeDays(
    new Date(new Date().getFullYear(), 0, 1),
    new Date(new Date().getFullYear() + 1, 0, 1)
  );

  let dailyCounts = [];
  if (displayMode === "recordCount") {
    dailyCounts = allDays.map((day) => {
      const dayStr = `${day.getMonth() + 1}-${day.getDate()}`;
      const count = records.filter((record) => {
        const recordDate = d3.timeDay(record.startTime);
        return recordDate.getTime() === day.getTime();
      }).length;
      return { date: day, count: count };
    });
  } else if (displayMode === "averageValue") {
    dailyCounts = allDays.map((day) => {
      const dayStr = `${day.getMonth() + 1}-${day.getDate()}`;
      const values =
        dailyData[dayStr] && dailyData[dayStr][dataType]
          ? dailyData[dayStr][dataType]
          : [];
      return {
        date: day,
        count: values.length ? d3.mean(values) : null,
      };
    });
  }

  console.log("dailyCounts", dailyCounts);
  console.log("dailyData", dailyData);

  const dateExtent = d3.extent(dailyCounts, (d) => d.date);
  const firstDay = d3.timeMonday(dateExtent[0]);
  const lastDay = d3.timeSunday(dateExtent[1]);

  const dateColorScale =
    displayMode === "recordCount"
      ? d3
          .scaleSequential()
          .domain([0, d3.max(dailyCounts, (d) => d.count)])
          .interpolator(
            d3.interpolateRgb("rgba(20, 20, 20,1)", "rgba(220, 220, 220,1)")
          )
      : gradientScales[dataType];

  const dateGroup = svg.append("g").attr("transform", `translate(25, -20)`);

  // Add day labels
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  dateGroup
    .selectAll(".dayLabel")
    .data(days)
    .enter()
    .append("text")
    .attr("class", "dayLabel")
    .attr("x", -25)
    .attr("y", (d, i) => i * (cellSize + cellPadding) + 5)
    .style("text-anchor", "start")
    .attr("dy", "0.32em")
    .style("fill", "white")
    .style("font-size", "8px")
    .text((d) => d);

  // Add month labels
  const months = d3.timeMonth.range(firstDay, lastDay);
  dateGroup
    .selectAll(".monthLabel")
    .data(months)
    .enter()
    .append("text")
    .attr("class", "monthLabel")
    .attr("x", (d) => {
      const weekOffset = d3.timeWeek.count(firstDay, d);
      return weekOffset * (cellSize + cellPadding);
    })
    .attr("y", -10)
    .style("text-anchor", "start")
    .style("fill", "white")
    .style("font-size", "8px")
    .text((d) => d3.timeFormat("%b")(d));

  dateGroup
    .selectAll(".dayCell")
    .data(dailyCounts)
    .enter()
    .append("rect")
    .attr("class", "dayCell")
    .attr("x", (d) => {
      const weekOffset = d3.timeWeek.count(firstDay, d.date);
      return weekOffset * (cellSize + cellPadding);
    })
    .attr("y", (d) => d.date.getDay() * (cellSize + cellPadding))
    .attr("width", cellSize)
    .attr("height", cellSize)
    .attr("fill", (d) => dateColorScale(d.count))
    .attr("stroke", "lightgrey")
    .attr("stroke-width", 0.3);

  // add anotation for the date distribution
  const annotation = dateGroup
    .append("g")
    .attr("class", "annotation")
    .attr("transform", `translate(-${margin.left}, 0)`);
  annotation
    .append("text")
    .attr("x", (49 * (cellSize + cellPadding)) / 2)
    .attr("y", height * 0.9)
    .style("fill", "lightgrey")
    .style("font-size", "10px")
    .text("Annual Distribution");

  // Add a legend for the date distribution
  const legend = svg
    .append("g")
    .attr("class", "legend")
    .attr("transform", `translate(-${margin.left}, 0)`);

  const legendNames = {
    temperature: "Temperature (°C)",
    humidity: "Humidity (%)",
    pressure: "Pressure (hPa)",
    gas: "Gas (kOhms)",
    noise: "Noise Level (dB)",
    mvc: "Count (MV)",
    nmvc: "Count (NMVC)",
    pc: "People Count",
    sp: "Sky Visibility (%)",
    tp: "Tree Visibility (%)",
  };

  const updateLegend = (dataType, legend) => {
    legend.selectAll("*").remove();

    const gradientScale = gradientScales[dataType];
    const dataDomain = gradientScale.domain();
    const endValue = dataDomain[1];
    if (!gradientScale) {
      console.error(`Gradient scale for data type "${dataType}" not found.`);
      return;
    }

    const formatColor = (color) => {
      const rgb = d3.rgb(color);
      return `rgb(${rgb.r},${rgb.g},${rgb.b})`;
    };

    const startColor = formatColor(gradientScale(0));
    const endColor = formatColor(gradientScale(endValue));
    const colors = [startColor, endColor];
    const gradientId = `gradient-${dataType}`;

    const defs = legend.append("defs");
    const linearGradient = defs
      .append("linearGradient")
      .attr("id", gradientId)
      .attr("x1", "0%")
      .attr("x2", "0%")
      .attr("y1", "0%")
      .attr("y2", "100%");

    linearGradient
      .selectAll("stop")
      .data(colors)
      .enter()
      .append("stop")
      .attr("offset", (d, i) => `${100 * (i / (colors.length - 1))}%`)
      .attr("stop-color", (d) => d);

    const legendHeight = height * 0.8;

    const legendYStart = -25;

    const rect = legend
      .append("rect")
      .attr("x", 30)
      .attr("y", legendYStart)
      .attr("width", 15)
      .attr("height", legendHeight)
      .style("fill", `url(#${gradientId})`);

    const numTicks = 5;
    const tickValues = d3.range(numTicks).map((d) => {
      return (endValue / (numTicks - 1)) * d;
    });

    const tickScale = d3
      .scaleLinear()
      .domain([0, endValue])
      .range([legendHeight, 0]);

    legend
      .selectAll(".tick")
      .data(tickValues)
      .enter()
      .append("text")
      .attr("class", "tick")
      .attr("x", 50)
      .attr("y", (d) => legendYStart + tickScale(d))
      .style("fill", "white")
      .style("font-size", "8px")
      .text((d) => d3.format(".2f")(d));

    const text = legend
      .append("text")
      .attr("x", 20)
      .attr("y", height / 2)
      .style("fill", "white")
      .style("font-size", "10px")
      .text(legendNames[dataType])
      .attr("transform", `rotate(-90, 20, ${height / 2})`);
  };

  updateLegend(dataType, legend);
}
