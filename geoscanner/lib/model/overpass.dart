import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'dart:convert'; // Import for JSON decoding

class OverpassData {
  final List<Node> nodes;
  final List<Edge> edges;

  OverpassData({required this.nodes, required this.edges});
}

class Node {
  final String id;
  final double lat;
  final double lon;

  Node({required this.id, required this.lat, required this.lon});
}

class Edge {
  final Node fromNode;
  final Node toNode;
  final String wayId;
  final double distance;

  Edge(
      {required this.fromNode,
      required this.toNode,
      required this.wayId,
      required this.distance});
}

Future<OverpassData> getOverpassData(
    double minLat, double minLon, double maxLat, double maxLon) async {
  const margin = 0.05; // Adjust margin as needed
  final dataMinLat = minLat + (maxLat - minLat) * margin;
  final dataMinLon = minLon + (maxLon - minLon) * margin;
  final dataMaxLat = maxLat - (maxLat - minLat) * margin;
  final dataMaxLon = maxLon - (maxLon - minLon) * margin;

  final overpassQuery = '''
    [out:json][timeout:300];
    (
      way($dataMinLat,$dataMinLon,$dataMaxLat,$dataMaxLon)
      ['highway'~'^(trunk|trunk_link|primary|primary_link|secondary|secondary_link|tertiary|tertiary_link)\$'];
      node(w);
    );
    out body;
  ''';

  final overpassUrl =
      'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(overpassQuery)}';

  print('Fetching Overpass data from URL: $overpassUrl');
  final response = await http.get(Uri.parse(overpassUrl));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final List elements = data['elements'];

    final List<Node> nodes = [];
    final List<Edge> edges = [];
    final Map<String, Node> nodesMap = {};

    for (var element in elements) {
      if (element['type'] == 'node') {
        final id = element['id'].toString();
        final lat = element['lat'];
        final lon = element['lon'];
        final node = Node(id: id, lat: lat, lon: lon);
        nodes.add(node);
        nodesMap[id] = node; // Add to the map
      }
    }
    var requestedDataCound = 0;
    for (var element in elements) {
      if (element['type'] == 'way') {
        final wayId = element['id'].toString();
        final nodeRefs =
            List<String>.from(element['nodes'].map((node) => node.toString()));
        print('nodeRefs: $nodeRefs');
        
        requestedDataCound += nodeRefs.length - 1;
      
        for (int i = 0; i < nodeRefs.length - 1; i++) {
          final fromNode = nodesMap[nodeRefs[i]];
          final toNode = nodesMap[nodeRefs[i + 1]];

          if (fromNode != null && toNode != null) {
            final distance = calculateDistance(
                fromNode.lat, fromNode.lon, toNode.lat, toNode.lon);
            edges.add(Edge(
                fromNode: fromNode,
                toNode: toNode,
                wayId: wayId,
                distance: distance));
          } else {
            print('Skipping invalid edge: fromNode=$fromNode, toNode=$toNode');
          }
        }
      }
    }

    print('Requested data count: $requestedDataCound');

    return OverpassData(nodes: nodes, edges: edges);
  } else {
    throw Exception('Failed to load Overpass data');
  }
}

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  // Haversine formula to calculate distance between two points
  const p = 0.017453292519943295;
  final a = 0.5 -
      cos((lat2 - lat1) * p) / 2 +
      cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

  return 12742 * asin(sqrt(a));
}
