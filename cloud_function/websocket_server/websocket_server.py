import asyncio
import websockets
import os

async def save_image(websocket, path):
    print(f"New connection from {websocket.remote_address}")
    try:
        async for message in websocket:
            if isinstance(message, bytes):
                print(f"Received message: {message}")

                # 找到第一个分隔符
                delimiter_index1 = message.find(b'\x00')
                if delimiter_index1 != -1:
                    # 解析 record_id
                    record_id = message[:delimiter_index1].decode('utf-8')
                    remaining_data = message[delimiter_index1+1:]

                    # 找到第二个分隔符
                    delimiter_index2 = remaining_data.find(b'\x00')
                    if delimiter_index2 != -1:
                        # 解析 timestamp
                        timestamp = remaining_data[:delimiter_index2].decode('utf-8')
                        image_data = remaining_data[delimiter_index2+1:]
                        
                        # 打印调试信息
                        print(f"Record ID: {record_id}")
                        print(f"Timestamp: {timestamp}")
                        print(f"Image data length: {len(image_data)}")

                        # 生成文件名并保存文件
                        file_name = f"{record_id}_{timestamp}.jpg"
                        with open(os.path.join(path, file_name), 'wb') as f:
                            f.write(image_data)
                        print(f"Saved image {file_name}")

                        # 发送确认消息
                        await websocket.send(f"Saved {file_name}")
                    else:
                        print("No second delimiter found in message.")
                else:
                    print("No first delimiter found in message.")
            else:
                print("Received non-binary message")
    except websockets.ConnectionClosed as e:
        print(f"Connection closed: {e}")
    except Exception as e:
        print(f"Error: {e}")

async def main():
    server_ip = "0.0.0.0"
    server_port = 8765
    save_path = "./images"

    if not os.path.exists(save_path):
        os.makedirs(save_path)

    async with websockets.serve(lambda ws, path: save_image(ws, save_path), server_ip, server_port):
        print(f"Server started at {server_ip}:{server_port}")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
