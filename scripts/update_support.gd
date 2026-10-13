extends RefCounted

const RELEASE_PATH := "res://distribution/release.json"
const PUBLIC_KEY_PATH := "res://distribution/update-public.pem"
const INSTALLED_PATH := "user://updates/installed.json"
const MAX_PACK_SIZE := 200 * 1024 * 1024

static func release_info() -> Dictionary:
    var value = JSON.parse_string(FileAccess.get_file_as_string(RELEASE_PATH))
    return value if value is Dictionary else {}

static func platform_key() -> String:
    return "macOS" if OS.get_name() == "macOS" else "Windows" if OS.get_name() == "Windows" else ""

static func authenticate(envelope: Dictionary, public_key: String) -> Dictionary:
    if not envelope.get("payload") is String or not envelope.get("signature") is String: return {}
    if envelope.payload.length() > 90000 or envelope.signature.length() > 2048: return {}
    var payload: PackedByteArray = Marshalls.base64_to_raw(envelope.payload)
    var signature: PackedByteArray = Marshalls.base64_to_raw(envelope.signature)
    var key := CryptoKey.new()
    if key.load_from_string(public_key, true) != OK: return {}
    var hash := HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(payload)
    if not Crypto.new().verify(HashingContext.HASH_SHA256, hash.finish(), signature, key): return {}
    var data = JSON.parse_string(payload.get_string_from_utf8())
    if not data is Dictionary or not data.has_all(["version", "build", "runtime", "platforms"]): return {}
    if not data.version is String or not data.runtime is String or not data.platforms is Dictionary: return {}
    if not (data.build is int or data.build is float) or data.build != int(data.build) or data.build < 1 or data.build > 100000000: return {}
    return data

static func platform_release(data: Dictionary) -> Dictionary:
    var asset = data.get("platforms", {}).get(platform_key(), {})
    if not asset is Dictionary or not asset.has_all(["url", "sha256", "size"]): return {}
    if not asset.url is String or not asset.url.begins_with("https://"): return {}
    if not asset.sha256 is String or asset.sha256.length() != 64 or not asset.sha256.is_valid_hex_number(false): return {}
    if not (asset.size is int or asset.size is float) or asset.size != int(asset.size) or asset.size < 1 or asset.size > MAX_PACK_SIZE: return {}
    return asset

static func pack_path(build: int) -> String:
    return "user://updates/game-%d.pck" % build

static func pack_matches(path: String, asset: Dictionary) -> bool:
    if not FileAccess.file_exists(path): return false
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() != int(asset.size): return false
    var hash := HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    while file.get_position() < file.get_length():
        hash.update(file.get_buffer(1024 * 1024))
    return hash.finish().hex_encode() == asset.sha256.to_lower()
