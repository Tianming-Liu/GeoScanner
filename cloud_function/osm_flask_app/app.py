import json
import networkx as nx
import osmnx as ox
from flask import Flask, request, jsonify, url_for
from shapely.geometry import Point, LineString
import geopandas as gpd
import logging
import os
from tools import * 
from network.algorithms import hierholzer

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.DEBUG)

@app.route('/get_osm', methods=['GET'])
def get_osm_data():
    lat = request.args.get('lat', type=float)
    lon = request.args.get('lon', type=float)
    radius = request.args.get('radius', default=500, type=int)
    network_type = request.args.get('network_type', default='walk', type=str)

    if lat is None or lon is None:
        return 'Latitude and Longitude are required', 400

    try:
        sensing_center = (lat, lon)
        G = ox.graph_from_point(sensing_center, dist=radius, network_type=network_type)
        nodes, edges = ox.graph_to_gdfs(G)
        nodes_json = json.loads(nodes.to_json())
        edges_json = json.loads(edges.to_json())

        return jsonify(nodes=nodes_json, edges=edges_json)
    except Exception as e:
        return f"Error processing request: {str(e)}", 500

@app.route('/process_graph', methods=['POST'])
def process_graph():
    try:
        logging.debug("Received request for process_graph")
        data = request.get_json()

        if not data:
            logging.error("Invalid data received")
            return "Invalid data", 400

        nodes = data.get('nodes')
        edges = data.get('edges')

        if nodes is None or edges is None:
            logging.error("Nodes and edges data are required")
            return "Nodes and edges data are required", 400

        logging.debug(f"Processing {len(nodes)} nodes and {len(edges)} edges")

        # Create a MultiDiGraph
        G = nx.MultiDiGraph()

        # Add nodes and initialize street_count
        for node in nodes:
            node_id = str(node['id'])
            G.add_node(node_id, x=node['longitude'], y=node['latitude'], osmid=node_id, street_count=0)

        # 添加边并更新节点的 street_count
        for edge in edges:
            try:
                # Extract edge information
                source, target, _ = edge['id'][1:-1].split(', ')
                source, target = str(source), str(target)  # Ensure node IDs are strings

                # Check if the source and target nodes exist
                if source in G.nodes and target in G.nodes:
                    G.add_edge(source, target, key=0, osmid=edge['id'], geometry=LineString([(p['longitude'], p['latitude']) for p in edge['points']]), highway='residential', length=10)
                    G.nodes[source]['street_count'] += 1
                    G.nodes[target]['street_count'] += 1
                else:
                    print(f"Skipping edge ({source}, {target}) because one of the nodes is missing")
            except Exception as e:
                print(f"Error processing edge {edge['id']}: {e}")

        # Set CRS and name
        G.graph['crs'] = "epsg:4326"
        G.graph['name'] = "custom_graph"

        # Convert to undirected graph
        if G.number_of_edges() > 0:
            graph = ox.utils_graph.convert.to_undirected(G)

            # Check if the node has no edges
            isolated_nodes = [node for node, degree in graph.degree if degree == 0]
            graph.remove_nodes_from(isolated_nodes)

            # Finds the odd degree nodes and minimal matching
            odd_degree_nodes = get_odd_degree_nodes(graph)
            pair_weights = get_shortest_distance_for_odd_degrees(graph, odd_degree_nodes)
            matched_edges_with_weights = min_matching(pair_weights)

            # List all edges of the extended graph including original edges and edges from minimal matching
            single_edges = [(u, v) for u, v, k in graph.edges]
            added_edges = get_shortest_paths(graph, matched_edges_with_weights)
            edges = map_osmnx_edges2integers(graph, single_edges + added_edges)

            # Finds the Eulerian path
            network = Network(len(graph.nodes), edges, weighted=True)
            eulerian_path = hierholzer(network)
            converted_eulerian_path = convert_integer_path2osmnx_nodes(eulerian_path, graph.nodes())
            double_edge_heap = get_double_edge_heap(G)

            # Finds the final path with edge IDs
            final_path = convert_path(graph, converted_eulerian_path, double_edge_heap)

            # Create waypoints for Flutter
            waypoints = []
            for i in range(0, len(final_path)):
                osm_node_id = final_path[i][0]
                if osm_node_id in graph.nodes:
                    node_data = graph.nodes[osm_node_id]
                    waypoint = {
                        "name": f'{osm_node_id}',
                        "latitude": node_data['y'],
                        "longitude": node_data['x'],
                        "isSilent": False
                    }
                    waypoints.append(waypoint)
                    if i == len(final_path) - 1:
                        osm_node_id = final_path[i][1]
                        if osm_node_id in graph.nodes:
                            node_data = graph.nodes[osm_node_id]
                            waypoint = {
                                "name": node_data.get("name", "N/A"),
                                "latitude": node_data['y'],
                                "longitude": node_data['x'],
                                "isSilent": False
                            }
                            waypoints.append(waypoint)

            # # Generate GIf and return URL
            # gif_filename = 'path_progression.gif'
            # gif_path = os.path.join('static', gif_filename)
            # create_path_animation_with_labels(graph, final_path, gif_filename=gif_path)

            # Calculate the total street length and route length
            total_street_length = calculate_total_street_length(graph) / 1000  # Convert to kilometers
            route_length = calculate_route_length(graph, final_path) / 1000  # Convert to kilometers

            return jsonify({
                "streetLength": str(total_street_length),
                "routeLength": str(route_length),
                "waypoints": waypoints
            })
        else:
            logging.error("The graph has no edges")
            return "The graph has no edges.", 400

    except Exception as e:
        logging.error(f"Error processing request: {str(e)}")
        return f"Error processing request: {str(e)}", 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
