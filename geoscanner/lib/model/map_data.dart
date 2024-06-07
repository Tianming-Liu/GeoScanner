class Vertex {
  final double lat;
  final double lng;
  Vertex(this.lat, this.lng);
}

class Edge {
  final Vertex start;
  final Vertex end;
  Edge(this.start, this.end);
}