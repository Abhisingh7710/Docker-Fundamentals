from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app) 

@app.route('/api/submit', methods=['POST'])
def handle_submit():
    data = request.get_json()
    
    name = data.get('name', 'Anonymous')
    email = data.get('email', 'N/A')
    message = data.get('message', '')
    
    print(print(f"Received data - Name: {name}, Email: {email}"))
    
    return jsonify({
        "status": "success",
        "message": f"Data received successfully for {name}!",
        "processedData": {
            "name": name.upper(),
            "email": email,
            "message_length": len(message)
        }
    }), 200

if __name__ == '__main__':
    # Bound to 0.0.0.0 so it can be accessed outside its specific container
    app.run(host='0.0.0.0', port=5000, debug=True)