require "./model"

# This is the instance persistence path emitted by Azu CLI's CRUD services.
# CQL 1.0.0 #attributes puts this JSON::Any directly into Hash(Symbol, DB::Any).
JsonProbeDocument.new("instance", JSON.parse(%({"active":true}))).save!
