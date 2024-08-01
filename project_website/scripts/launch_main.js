import { db, collection, getDocs } from "./firebase.js";
import config from "./config.js";

let dataPoints = [];
let records = [];
let hourlyData = {};
let map;
let overlay;
let scatterplotLayer;
let pathLayer;
let animationFrameId;
const speed = 1;
let pathsData = [];
let isAnimating = false;

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
  const min = Math.min(...dataPoints.map((dp) => dp[type]));
  const max = Math.max(...dataPoints.map((dp) => dp[type]));
  const range = max - min;
  const normalizedValue = (value - min) / range;
  const colorValue = Math.floor(normalizedValue * 255);
  return [colorValue, 0, 255 - colorValue, 100];
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
          }
        });
        pathsData.push(path);
      }
    });
  }

  initializeMap(dataPoints, pathsData);
  createTimelineChart(records, hourlyData, "temperature");
}

displayAllUserRecords().catch((error) => {
  console.error("Error fetching user records: ", error);
});

function initializeMap(dataPoints, paths) {
  mapboxgl.accessToken = config.MAPBOX_ACCESS_TOKEN;
  map = new mapboxgl.Map({
    container: "map",
    style: "mapbox://styles/tianmingliu/clypw698q009p01qr4vwf5c17",
    center: [0.024331, 51.515015],
    zoom: 16,
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

document.getElementById("dataControl").addEventListener("change", (event) => {
  const dataType = event.target.value;
  console.log("Data type control changed:", dataType);

  // 更新地图上的点
  dataPoints.forEach((point) => {
    point.color = getColorByValue(point[dataType], dataType);
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
  console.log("Color control updated:", dataType);

  d3.select("#timeline").html("");
  createTimelineChart(records, hourlyData, dataType);
});

function createTimelineChart(records, hourlyData, dataType) {
  const timelineDiv = d3.select("#timeline");
  console.log("Creating timeline chart for data type:", dataType);
  const circleOffset = 20; // Distance above the rectangles to place the circles
  const margin = {
    top: 20 + circleOffset + 20,
    right: 20,
    bottom: 30 + 20,
    left: 100,
  }; // Increased left margin for legend
  const timelineHeight = document.getElementById("timeline").offsetHeight;
  const width =
    document.getElementById("timeline").offsetWidth -
    margin.left -
    margin.right;
  const height = timelineHeight - margin.top - margin.bottom;

  const svg = timelineDiv
    .append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
    .append("g")
    .attr("transform", `translate(${margin.left},${margin.top})`);

  const x = d3.scaleLinear().domain([0, 24]).range([0, width]);

  const y = d3
    .scaleBand()
    .domain(d3.range(records.length))
    .range([0, height])
    .padding(0.05);

  // Add bottom x axis with additional offset
  svg
    .append("g")
    .attr("transform", `translate(0,${height + 20})`)
    .call(d3.axisBottom(x).ticks(24))
    .selectAll("text")
    .style("fill", "white")
    .style("font-size", "10px");

  // Add top x axis
  svg
    .append("g")
    .attr("transform", `translate(0, -20)`)
    .call(d3.axisTop(x).ticks(24))
    .selectAll("text")
    .style("fill", "white")
    .style("font-size", "10px");

  svg.selectAll(".domain, .tick line").style("stroke", "lightgrey");

  // Calculate the record count for each hour using start time's hour
  const recordCounts = d3.range(24).map((hour) => {
    const count = records.filter((record) => {
      return record.startTime.getHours() === hour;
    }).length;
    return count;
  });

  const colorScale = d3
    .scaleSequential()
    .domain([0, d3.max(recordCounts)])
    .interpolator(
      d3.interpolateRgb("rgba(73, 50, 64,1)", "rgba(255, 0, 153,1)")
    );

  const durationExtent = d3.extent(records, (record) => {
    const startTime =
      record.startTime.getHours() + record.startTime.getMinutes() / 60;
    const endTime =
      record.endTime.getHours() + record.endTime.getMinutes() / 60;
    return endTime - startTime;
  });

  const radiusScale = d3.scaleSqrt().domain(durationExtent).range([5, 15]);

  // Add rectangles for each hour of the day, colored by the number of records
  // Add outer rectangles for the black border effect
  svg
    .selectAll("outerRect")
    .data(recordCounts)
    .enter()
    .append("rect")
    .attr("x", (d, i) => x(i))
    .attr("y", 0)
    .attr("width", width / 24)
    .attr("height", height)
    .attr("fill", "none")
    .attr("stroke", "black")
    .attr("stroke-width", 2);

  // Add inner rectangles for the colored fill
  svg
    .selectAll("innerRect")
    .data(recordCounts)
    .enter()
    .append("rect")
    .attr("x", (d, i) => x(i) + 1)
    .attr("y", 1)
    .attr("width", width / 24 - 3)
    .attr("height", height - 3)
    .attr("stroke", "white")
    .attr("stroke-width", 0.15)
    .attr("fill", (d) => colorScale(d))
    .attr("rx", 5)
    .attr("ry", 5);

  records.forEach((record, index) => {
    const startTime =
      record.startTime.getHours() + record.startTime.getMinutes() / 60;
    const endTime =
      record.endTime.getHours() + record.endTime.getMinutes() / 60;
    const duration = endTime - startTime;
    const radius = radiusScale(duration);

    const startX = x(startTime);
    const endX = x(endTime);
    const cxValue = (startX + endX) / 2;

    // Adjust the cyValue to a fixed height above the rectangles
    const cyValue = -circleOffset / 2; // for example, 10 pixels above the rectangles

    svg
      .append("circle")
      .attr("cx", isNaN(cxValue) ? 0 : cxValue)
      .attr("cy", cyValue) // Use fixed height above rectangles
      .attr("r", radius)
      .attr("fill", "rgba(255, 255, 255, 0.75)")
      .attr("stroke", "black")
      .attr("stroke-width", 0.2);
  });

  // Add legend
  const legendData = [
    { type: "temperature", color: "red" },
    { type: "humidity", color: "blue" },
    { type: "pressure", color: "green" },
    { type: "gas", color: "orange" },
    { type: "noise", color: "purple" },
    { type: "mvc", color: "brown" },
    { type: "nmvc", color: "pink" },
    { type: "pc", color: "cyan" },
    { type: "sp", color: "yellow" },
    { type: "tp", color: "grey" },
  ];

  const legend = svg
    .append("g")
    .attr("class", "legend")
    .attr("transform", `translate(-${margin.left}, 0)`);

  legendData.forEach((d, i) => {
    legend
      .append("rect")
      .attr("x", 0)
      .attr("y", i * 20)
      .attr("width", 18)
      .attr("height", 18)
      .style("fill", d.color);

    legend
      .append("text")
      .attr("x", 24)
      .attr("y", i * 20 + 9)
      .attr("dy", ".35em")
      .style("fill", "white")
      .text(d.type);
  });

  const dataTypeRanges = {
    temperature: [0, 40],
    humidity: [0, 100],
    pressure: [950, 1050],
    gas: [0, 500],
    noise: [0, 100],
    mvc: [0, 10],
    nmvc: [0, 10],
    pc: [0, 100],
    sp: [0, 100],
    tp: [0, 100],
  };

  Object.keys(hourlyData).forEach((hour) => {
    const data = hourlyData[hour][dataType];
    if (data && data.length > 0) {
      const range = dataTypeRanges[dataType] || [d3.min(data), d3.max(data)];
      const histogram = d3.histogram().domain(range).thresholds(10)(data);

      const xScale = d3
        .scaleLinear()
        .domain([0, d3.max(histogram, (d) => d.length)])
        .range([1, width / 24 - 3]);

      const barHeight = (height - 3) / histogram.length - 1;

      const extendedHistogram = [
        { x0: range[0], length: 0 }, // Set y value to 0 for the starting point
        ...histogram,
        { x0: range[1], length: 0 }, // Set y value to 0 for the ending point
      ];

      const line = d3
        .line()
        .x((d) => xScale(d.length))
        .y((d, i) => i * barHeight + barHeight / 2)
        .curve(d3.curveBasis);

      svg
        .append("path")
        .datum(extendedHistogram)
        .attr("fill", "none")
        .attr("stroke", "white")
        .attr("stroke-width", 1)
        .attr("transform", `translate(${x(hour) + 1}, 0)`)
        .attr("d", line);
    }
  });

  console.log("Timeline chart created for data type:", dataType);
}
