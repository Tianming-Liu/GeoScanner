import osmnx as ox
import json
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/get_osm', methods=['GET'])
def get_osm_data():
    lat = request.args.get('lat', type=float)
    lon = request.args.get('lon', type=float)
    radius = request.args.get('radius', default=500, type=int)

    if lat is None or lon is None:
        return 'Latitude and Longitude are required', 400

    try:
        sensing_center = (lat, lon)
        G = ox.graph_from_point(sensing_center, dist=radius, network_type="walk")
        nodes, edges = ox.graph_to_gdfs(G)
        nodes_json = json.loads(nodes.to_json())
        edges_json = json.loads(edges.to_json())

        return jsonify(nodes=nodes_json, edges=edges_json)
    except Exception as e:
        return f"Error processing request: {str(e)}", 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
