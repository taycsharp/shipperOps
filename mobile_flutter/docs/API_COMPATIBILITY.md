# API Compatibility Notes

This Flutter app has been adjusted for the upgraded production backend.

## Security change

The upgraded backend protects most routes with JWT. The app now logs in with:

```txt
POST /auth/login
GET  /auth/me
```

The token is sent in every protected request:

```txt
Authorization: Bearer <token>
```

## Endpoint changes

Old item endpoint:

```txt
POST /order-items/{item_id}/status
```

Upgraded endpoint used by this app:

```txt
POST /orders/{order_id}/items/{item_id}/status
```

## Proof of delivery

The app now uploads images using multipart form data:

```txt
POST /orders/{order_id}/proof
field: file
optional fields: receiver_name, delivery_note
```

## Location update

The location endpoint is authenticated now:

```txt
POST /locations/update
```

A shipper token can only update its own shipper profile. Admin/dispatcher tokens can access broader data, but this app is designed for shipper operation.
