==================================
Access Control Manager APIs
==================================

.. contents:: Table of Contents

Overview
=========

This document describes the https/json APIs for the Access Control Manager (ACM) component of Cloud Foundry. 

For an overview of how the ACM component interacts with other components in the Cloud 
Foundry system see `Interactions Between UAA, CC, CS and VMC <UAA-CC-CS-Interactions>`__.

The ACM is a service which manages access control lists and calculates access decisions for specific user and permissions 
relative to an object. The object is identified by a GUID and the ACM has no other semantic 
content of the object. The ACM supports definition of arbitrary permission sets. 

Access to the object can be controlled by defining an Access Control Entry (ace) on the object for the user. 
The ACM has an API to support subsequent authorization decisions. A request can be made to the ACM
to check whether a user has a permission on an object.

In the case of the cloud controller, an app space could be an ACM object. A permission set is defined for the 
allowed permissions of an app space. The ACM enables users to be 
assigned permissions in the app space and makes authorization decisions for the cloud controller 
by looking up the Access Control List (acl) of the app space object.

The design is intended to be as general as possible so that it can be used by other Cloud Foundry 
components as well.


ACM Entities
============

**Object**

    An object is an entity to which permissions are tied to and upon which access decisions are made. 
    Objects typically contain an id, a list of acceptable permissions, and an access control list (ACL) 
    that determines specific permissions granted to subjects.

**Subject**

    A Subject is an entity to which permission can be granted.  It can be a User or a Group.

**Permission**

    A permission is a named operation or feature of a client,
    e.g. "create_app", but it is opaque to the ACM.  The meaning of a
    permission is interpreted by the client of the ACM.

**ACL and ACE**

    An Access Control List (ACL) is attached to an object and consists of a list of access control entries 
    (ACE), which are permission/subject pairs. For example, an object the represents an app_space could 
    contain an ACE of "create_app"/"developers" which the Cloud Controller could use to decide if a user is 
    allowed to create an app. 

    The ACL on an object is of the form: [ {*permission*, *subject*}, {*permission*, *subject*}, ... ]
    
    For example: [ {create_app, developers}, {create_app, joe}, {delete_app, joe}, {bind_app, developers}, ...]

**Permission Sets**

    A permission set contains a collection of permission names. One or more permission sets must 
    be specified when an object is created. Only ACEs with permissions from the specified sets are 
    allowed on the object. A single permission name will not be allowed in multiple permission sets.
    
    Although the API supports multiple permission sets for an object, the implementation for now 
    will only support a single permission set for an object.

.. DS: the example below seems realistic enough and AppSpace only has
.. *one* permission set.  Why not restrict it that way at least to
.. start with?
.. JD: there probably is a need to have an object use multiple permission sets.
.. we're restricting it to one right now because of the use-cases that we're
.. discussing but we've kept the schema open for change. Neither the code nor
.. the tests support multiple permission sets per object.

.. DS: I wonder if after all "Object Type" might be a useful name for
.. a wrapper for a named set of permissions, since they are always
.. associated with an Object?
.. JD: It depends how you look at it. Initially, we did have the type of object define
.. the operations that can be performed on it. The feedback we've received supports
.. having permission sets somewhat like schemas that restrict the permission names that
.. can be used in the acl of an object.
.. To move forward, we will implement it using permission sets.

**Group**

    A Group is an entity that contains a set of users. A group is also
    an object (or can be associated with one) which provides access
    control decisions for modifications to the itself.

ACM Value Objects
=================

These are not entities in their own right, but can be a field in an
entity (where necessary).

**Additional Info**

    Can be used by clients to add mnemonic data to an
    entity to aid with administration by human users, e.g. if the ACM
    needed a UI these would be useful hints.

**Metadata**

    Carries information about schema and created/modified
    timestamps.

API Overview
==============

The ACM has an API to support the following high level operations.

- CRUD operations for permission sets
- CRUD operations for objects
- CRUD operations for groups
- Calculate an access decision on an object for specific subject and permission

Let's illustrate how the cloud controller (CC) would enable collaboration spaces as an example of an ACM client:
 
    Prior to using the ACM API for the first time, the ACM client must makes calls to the ACM 
    to provision permission sets. For example, to control access to an AppSpace 
    the cloud controller could define a permission set::

        { 
         name: "AppSpace",
         permissions: ["create_app", "create_service", "delete_app", "delete_service", "view_app_logs", "restart_app"]
        }

    As part of the API call to create an object representing an AppSpace, the CC would specify the object is to use 
    the ``AppSpace`` permission set and an initial ACL.  Here's a representation of the new AppSpace with an empty ACL::

        { id: "dsfaks-27364gf-dhjfg", name: "MyApps", permissionSets: ["AppSpace"], acl: [] }

    The ACM returns a GUID for the new object which would be stored by the CC for
    subsequent operations. The CC would then call the ACM to modify the ACL as needed -- 
    though only with permissions from the AppSpace permission set. 

    At the access decision point for the AppSpace, the cloud controller calls the ACM with
    the GUID of the AppSpace, the user's id and the permission required. The ACM returns a true/false
    decision.  Bulk operations for more efficient permission processing are also supported.


Versioning of Resource Representations
----------------------------------------

Versioning of the format of resources such as objects or groups is based on the X-ACM-Schema-Version
HTTP header in the response from the ACM.

The ACM response will always use the latest schema.  
However, different versions of the schema can be returned by setting a request header of the same name
to the required schema.

For example, 

    X-ACM-Schema-Version: urn:acm:schemas:1.0

will return a response with the schema version urn:acm:schemas:1.0

The request/response schema versioning element is depicted in the subsequent sections. 
Future versions of the schema may be defined but clients can always request versions that 
they support using this method.

.. _`etag header`:

Object Versioning
---------------------

Each HTTP call to modify an object must include an ETag which identifies which version 
of the object is being modified. When using a PUT, the ETag read from a prior operation such as a GET 
should be passed unchanged. If the object has been modified since that GET, the operation will 
return a ``409 Conflict`` error due to potentially conflicting changes.

See the the `etag section of HTTP 1.1 <http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.19>`__ .

There is also a `section in the SCIM spec about etags <http://www.simplecloud.info/specs/draft-scim-rest-api-01.html#etags>`__.


Authentication to the API
--------------------------

APIs may be authenticated using simple HTTP basic authentication using a client identifier and shared secret that
is configured in the client and the ACM instance. 

.. DS: Why not use OAuth2/OpenId Connect, that way the UAA handles
.. authentication?  I think it will simplify the message and reduce
.. potential confusion among clients if we stick to OAuth2.

.. DO: Dave, I see your point. I don't want to preclude OAuth2, but I 
.. don't want to require OAuth or the UAA either. Right
.. now the ACM is completely decoupled from the UAA and I think that's a good
.. thing, but I can also see it would be nice for the UAA to consistently 
.. handle all authentication. 
.. OTOH, to use the UAA the ACM would have to register with the UAA as a client
.. and someone would have to manage the CC's identity in the UAA, token
.. grants/revocations, etc. It seems to me just configuring a shared secret
.. between the CC and ACM for service-to-service authentication is simpler and
.. sufficient. OAuth2 is a really good hammer, but this is a really small nail. 

.. DS: Point taken on hammer and nail.  I guess if we only have one or
.. two fixed clients then a shared secret is easy for everyone.  If
.. ACM became a service in user app land, then it would need to be
.. more dynamic and also more consistent.  So we can postpone this
.. discussion until we need dynamic client registration and/or
.. delegated authentication.

Example Permissions to Manage Objects and ACLs
-----------------------------------------------

The ACM does not implement any specific permissions to provide access control to the objects and ACLs it manages.
However, the ACM does support APIs to manage a set of entities such as objects, groups, permission sets based on
the authentication of the client making the request, e.g. the cloud controller. Therefore, it is up the ACM client
to determine what permissions are required for modification to the ACLs of an object, or to update group
membership. The ACL client would call the ACM to check permissions of its choosing, and then call the ACM with the
update request if it's allowed. 

**Grant**

    For example, the client could define a permission called "grant". The intent would be that users with the 
    grant permission are allowed to assign some permissions to other users -- but only the subset of permissions
    that they have. In other words, a user with the 'grant'
    permission could add an ACE to an object if was for a permission the user also had. 
    
    To implement this permission, the client would define 'grant' with the ACM in a permission set used by the
    relevant object. When it got a request to modify the ACL of the object, it would first check that the user 
    had the 'grant' permission and all permissions in the new ACEs by calling the ACM access check API with the
    aggregate set of permissions. If the access check were successful, the client would call the ACM with the
    modifications to the ACL. 
    
**Admin**

    Another common permission to manage updates to the ACL is an Administrator model. Users with the Admin
    permission can only manage the ACLs, but they can give permissions they don't have themselves. This is useful
    so that an administrator does not need to have the permissions for operations not involved with controlling
    system access settings.
    
    To implement this permission, the client would define 'admin' with the ACM in permission set used by the
    relevant object. When it got a request to modify the ACL of the object, it would first check that the user 
    had the 'admin' permission by calling the ACM access check API. If the access check were successful, the 
    client would call the ACM with the modifications to the ACL.  


HTTP Status Codes
-------------------

The following table describes the HTTP status codes and what they mean in the context of the 
ACM API

=========================== ======================= ===================================
Code                        Method                  Explanation
=========================== ======================= ===================================
200 OK                      GET                     No error.
201 CREATED                 POST                    Creation of an object was successful.
304 NOT MODIFIED            GET                     The object hasn't changed since the 
                                                    time specified in the request's 
                                                    If-Modified-Since header.
400 BAD REQUEST             *any*                   Invalid request URI or header, or 
                                                    unsupported nonstandard parameter.
401 UNAUTHORIZED            *any*                   Authorization required.
403 FORBIDDEN               *any*                   Unsupported standard parameter, or 
                                                    authentication or authorization failed.
404 NOT FOUND               GET, PUT, DELETE        Object not found.
409 CONFLICT                PUT, DELETE             Specified version number doesn't 
                                                    match object's latest version number.
500 INTERNAL SERVER ERROR   *any*                   Internal error. This is the default 
                                                    code that is used for all unrecognized server errors.
=========================== ======================= ===================================


Error Response Payloads
------------------------

======================= ==============  ===================================
Property                Type            Description
======================= ==============  ===================================
code                    number          error code
description             string          description of the error
uri                     string          Location where further information on this error code can be obtained
meta                    object          Meta information about this entity
======================= ==============  ===================================

An example of an error payload is as follows::

    {
       "code":100,
       "description":"An unknown internal error occurred",
       "meta":{
          "object_id":"e0c46e6b-a89d-46cc-abd3-46553ffb14dc",
          "schema":"urn:acm:schemas:1.0"
       }
    }


Error code ranges

.. note:: TODO - For now, error codes between 1000-2000 will be returned

.. DS: I know the cloud controller has a numeric error identifier, but
.. OAuth2 has string identifiers for error codes, and it's a lot more
.. friendly.  WDYT?

.. DO: I don't have a strong opinion. Advantages for error numbers are
.. 1) it's clear they are error codes -- not for display and should not be localized. 
.. 2) it's what existing components do.
.. Advantages for strings:
.. 1) much easier debugging
.. 2) it's what OAuth2 does -- though OAuth2 has already had some difficulty
.. preventing people from directly displaying or attempting to add
.. localization tags to the errors. 
.. All in all, I think I'd prefer strings, but I'll let Joel argue this one.
.. JD: The strings look great. I'm just staying consistent with the cloudfoundry
.. components. All of them use either exactly that format or some variant of the same.


Operations on Permission Sets
==================================

Permission Set Schema
----------------------------------

Attributes

.. note:: 
    DO: in this rev I have opted to use 'name' as the immutable identifier for
    permission sets. We may want to use ids to allow permission sets to be 
    renamed, but it just did not seem to be worth the indirection for the 
    expected use cases.
    JD: At the moment, I do not see a compelling reason for renaming a permission set. 
    If the operations allowed on an object need to be re-arranged, a new permission set 
    can be created and added to the object. Some operations can then be moved to the new 
    permission set using a permission set update.

======================= ============== ===================================
Property                Type           Description
======================= ============== ===================================
name                    string         name of this permission set. Must be unique across the ACM.
additional_info         object         optional - additional information this object.
permissionSet           Array[String]  Set of object permissions for this type.
meta                    object         Meta information about this entity.
======================= ============== ===================================

Example::

    {
       "name":"app_space",
       "permissionSet": [
             "read_app",
             "update_app",
             "read_app_logs",
             "read_service",
             "write_service"
       ],
       "meta":{
          "updated":1273740902,
          "created":1273726800,
          "schema":"urn:acm:schemas:1.0"
       }
    }
    

Create Permission Set: POST /permission_sets
------------------------------------------------------------------------------------

Creates a permission set

===============  ===================================
HTTP Method      POST
URI              /permissions
Request Format   Refer to the `Permission Set Schema`_
Response Format  Refer to the `Permission Set Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
===============  ===================================

A permission set cannot contain duplicate permissions. If a permission is already assigned to 
another permission set and is referenced in this update, the permission will be removed from it's 
previous assignment and added to the updated permission set.


Update Permission Set: PUT /permission_sets/*name*
------------------------------------------------------------------------------------

Complete update of a permission set.

===============  ===================================
HTTP Method      PUT
URI              /permissions/*name*
Request Format   Refer to the `Permission Set Schema`_
Response Format  Refer to the `Permission Set Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
===============  ===================================

The permission set update replaces all the properties of a permission set. The "name"
property in the request is ignored. 

If an operation of a permission set assigned to an object is already referenced in an acl of any
object, the operation cannot be removed from the permission set. An attempt to perform such an 
operation will result in an HTTP 400.

If a permission is already assigned to another permission set and is referenced in this update, the 
permission will be removed from it's previous assignment and added to the updated permission set.


Get Permission Set: GET /permission_sets/*name*
------------------------------------------------------------------------------------

Gets the json representation of a permission set.

===============  ===================================
HTTP Method      GET
URI              /permissions/*name*
Request Format   N/A
Response Format  Refer to the `Permission Set Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================

To request specific versions of the permission set schema, see "Versioning of Resource Representations".

Delete Permission Set: DELETE /permission_sets/*name*
--------------------------------------------------------------------------------------

Deletes a permission set.

===============  ===================================
HTTP Method      DELETE
URI              /permissions/*name*
Request Format   N/A
Response Format  N/A
Response Codes   | 200 - Operation was successful
    			 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================

If the permission set to be deleted is referenced by an object, it cannot be deleted until that 
reference ceases to exist. 


Operations on Users/Groups
==================================

User/Group Schema
----------------------------------

Attributes

======================= ============== ===================================
Property                Type           Description
======================= ============== ===================================
id                      string         identifier for this user.
type                    string         indicates whether this is a user or a group
additional_info         string         additional information about this user/group
members                 Array[string]  optional - members if this is a group
meta                    object         Meta information about this entity.
======================= ============== ===================================

Example::

    {
       "id":"ab959740-6e1d-11e1-b0c4-0800200c9a66",
       "type":"user",
       "additional_info":"Name: John Doe",
       "meta":{
          "updated":1273740902,
          "created":1273726800,
          "schema":"urn:acm:schemas:1.0"
       }
    }


    
    {
       "id":"g-1cf380a0-6e1e-11e1-b0c4-0800200c9a66",
       "type":"group",
       "additional_info":"Name: Developers",
       "members":["ab959740-6e1d-11e1-b0c4-0800200c9a66",
                  "2fb80d81-7a7e-43f4-9b35-de7ccf7ba394",
                  "51234b9f-2017-498b-bbb5-566db19b98ec"
       ],
       "meta":{
          "updated":1273740902,
          "created":1273726800,
          "schema":"urn:acm:schemas:1.0"
       }
    }
    

Create User: POST /users/*user_id*
------------------------------------------------------------------------------------

Creates a user

===============  ===================================
HTTP Method      POST
URI              /users/*user_id*
Request Format   Refer to the `User/Group Schema`_
Response Format  Refer to the `User/Group Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
===============  ===================================

The user id provided must be unique. If no user id is provided, the ACM will 
generate a random user id for that user.


Get User: GET /users/*user_id*
------------------------------------------------------------------------------------

Gets the json representation of a user

===============  ===================================
HTTP Method      GET
URI              /users/*user_id*
Request Format   N/A
Response Format  Refer to the `User/Group Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================


Delete User: DELETE /users/*user_id*
--------------------------------------------------------------------------------------

Deletes a permission set.

===============  ===================================
HTTP Method      DELETE
URI              /users/*user_id*
Request Format   N/A
Response Format  N/A
Response Codes   | 200 - Operation was successful
    			 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================

Deleting a user will remove all references of that user from the ACM including from 
groups and ACLs.


Create Group: POST /groups/*group_id*
------------------------------------------------------------------------------------

Creates a group

===============  ===================================
HTTP Method      POST
URI              /users/*group_id*
Request Format   Refer to the `User/Group Schema`_
Response Format  Refer to the `User/Group Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
===============  ===================================

The group id provided must be unique. If no group id is provided, the ACM will 
generate a random user id for that user.

The group id must be prefixed with the string "g-".


Get group information: GET /groups/*group_id*
------------------------------------------------------------------------------------

Gets the json representation of a group

===============  ===================================
HTTP Method      GET
URI              /groups/*group_id*
Request Format   N/A
Response Format  Refer to the `User/Group Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================


Delete Group: DELETE /groups/*group_id*
--------------------------------------------------------------------------------------

Deletes a group

===============  ===================================
HTTP Method      DELETE
URI              /groups/*group_id*
Request Format   N/A
Response Format  N/A
Response Codes   | 200 - Operation was successful
    			       | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================

Deleting a group will remove all references of that group from the ACM including from 
ACLs.


Update Group: PUT /groups/*group_id*
------------------------------------------------------------------------------------

Performs a full update of a group

===============  ===================================
HTTP Method      PUT
URI              /users/*group_id*
Request Format   Refer to the `User/Group Schema`_
Response Format  Refer to the `User/Group Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
===============  ===================================

The group id provided must exist and be unique. The group id must be prefixed with 
the string "g-".


Add a member to a group: PUT /groups/*group_id*/members/*user_id*
------------------------------------------------------------------------------------

Adds member with user id *user_id* to group *group_id*

===============  ===================================
HTTP Method      PUT
URI              /groups/*group_id*/members/*user_id*
Request Format   N/A
Response Format  Refer to the `User/Group Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================

The group id must be prefixed with the string "g-".


Remove a member from a group: DELETE /groups/*group_id*/members/*user_id*
------------------------------------------------------------------------------------

Removes member with user id *user_id* from the group *group_id*

===============  ===================================
HTTP Method      DELETE
URI              /groups/*group_id*/members/*user_id*
Request Format   N/A
Response Format  Refer to the `User/Group Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================

The group id must be prefixed with the string "g-".




Operations on Objects
==================================

Object Schema
----------------------

Attributes

======================= ==============  ===================================
Property                Type            Description
======================= ==============  ===================================
id                      string          immutable identifier (not to be included in a request). 
                                        It is returned in the response.
permission sets         Array[String]   names of permission sets allowed in this object. Currently,
										                    the API only supports a single permission set.
additional_info         object          optional - additional information this object.
acl                     object          map of object permissions => set of users.
meta                    object          meta information about this entity.
======================= ==============  ===================================

Example::

    {
       "permissionSets":["app_space"],
       "id":"54947df8-0e9e-4471-a2f9-9af509fb5889",
       "additional_info": {"org":"vmware", "name":"www_staging"},
       "acl": {
             "read_app": ["3749285", "4a9a8c60-0cb2-11e1-be50-0800200c9a66"],
             "update_app": ["3749285", "4a9a8c60-0cb2-11e1-be50-0800200c9a66"],
             "read_app_logs": ["3749285", "4a9a8c60-0cb2-11e1-be50-0800200c9a66", "g-d1682c64-040f-4511-85a9-62fcff3cbbe2"],
             "read_service": ["3749285", "4a9a8c60-0cb2-11e1-be50-0800200c9a66"],
             "write_service": ["3749285", "4a9a8c60-0cb2-11e1-be50-0800200c9a66"]
       },
       "meta":{
          "updated":1273740902,
          "created":1273726800,
          "schema":"urn:acm:schemas:1.0"
       }
    }

Create Object: POST /objects
------------------------------------------------------------------------------------

Create Object

===============  ===================================
HTTP Method      POST
URI              /objects
Request Format   Refer to the `Object Schema`_
Response Format  Refer to the `Object Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
===============  ===================================

The service responds with an instance of the object that was created.

Complete Object Update: PUT /objects/*id*
------------------------------------------------------------------------------------

Complete update of an object.

===============  ===================================
HTTP Method      PUT
URI              /objects/*id*
Request Format   Refer to the `Object Schema`_
Response Format  Refer to the `Object Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
===============  ===================================

The object update replaces all the properties of an object. The "id"
property in the request is ignored. 

The service responds with an instance of the object in its updated state.

.. _`partial update`:

Partial Update to an object: PUT /objects/*id*
------------------------------------------------------------------------------------

Sometimes, instead of updating the entire object, it may be necessary to update only a small
section of the schema, e.g. add a user to an ACL.

A partial update allows the caller to only specify the addition/update to the object. The API 
requires an additional header in the request to indicate that this is for a partial
update.

=================  ===================================
HTTP Method        PUT
URI                /objects/*id*
Additional header  X-HTTP-Method-Override PATCH
Request Format     Refer to the `Object Schema`_
Response Format    Refer to the `Object Schema`_ 
Response Codes     | 200 - Operation was successful
                   | 400 - Bad request
                   | 401 - Not authorized
=================  ===================================

The service responds with an instance of the object schema.

Since the ACL of some objects can get large, a PATCH operation allows for a partial update.

There are three types of attributes that will be affected differently depending on their type

* Singular attributes:
  Singular attributes in the PATCH request body replace the attribute on the Object.
  
* Complex attributes:
  Complex Sub-Attribute values in the PATCH request body are merged into the complex attribute on the Object.
  
* Plural attributes:
  Plural attributes in the PATCH request body are added to the plural attribute on the Object if 
  the value does not yet exist or are merged into the matching plural value on the Object if the 
  value already exists. Plural attribute values are matched by comparing the value Sub-Attribute 
  from the PATCH request body to the value Sub-Attribute of the Object. Plural attributes that do 
  not have a value Sub-Attribute (for example, users) cannot be matched for the purposes of 
  partially updating an an existing value. These must be deleted then added. Similarly, plural 
  attributes that do not have unique value Sub-Attributes must be deleted then added.

For some examples see `Example Requests and Responses`_.

.. note:: 
    DO: This partial update mechanism is derived from SCIM and is good in that it would allow 
    update of various parts of a resource, even though we haven't (so far) brought in the 
    SCIM syntax for deleting an arbitrary attribute value. Nevertheless, I am wondering
    if all of this is worth it for the current needs of the ACM. If we didn't support partial 
    update of an Object and only supported add/remove of an ACE, we could remove all of this 
    complexity.
    
    Create, Full Update (Put), Get, and Delete Object would all work as described. Adding and removing 
    individual subject/permission pairs could be done like this:
    
    PUT /objects/*id*/acl/*subject*/*permission*
    DELETE /objects/*id*/acl/*subject*/*permission*
    
    Following this model we could also easily support add permissions for a user, get all permissions 
    for a user, delete all permissions for a user:

    POST /objects/*id*/acl/*subject*    (permissions)
    GET /objects/*id*/acl/*subject*
    DELETE /objects/*id*/acl/*subject*
    
    A similar approach could be used with Group members:

    POST /groups/*id*/members           (users)
    DELETE /groups/*id*/members/*user*    


Get Object: GET /objects/*id*
------------------------------------------------------------------------------------

Read ACM object

===============  ===================================
HTTP Method      GET
URI              /objects/*id*
Request Format   N/A
Response Format  Refer to the `Object Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
===============  ===================================

The service responds with the json for the entire object. To request specific versions of the 
object schema, see "Versioning of Resource Representations".



List of Users that have access to an object: GET /objects/*id*/users
------------------------------------------------------------------------------------

===============  ===================================
HTTP Method      GET
URI              /objects/*id*/users
Request Format   N/A
Response Format  As below
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
===============  ===================================

The response for this request is something like::

    GET /objects/0a59970a-3cf1-44a5-996d-eed9c0fe1c1e/users
    Host: internal.vcap.acm.com
    Accept: application/json
    Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==

    HTTP/1.1 200 OK
    Content-Type: application/json

    {
       "00ccb9a7-c545-4881-98de-1589114a5b1b":[
          "read_appspace"
       ],
       "c34c43cb-ff0b-4c3c-a5a8-683ea33d7bf8":[
          "write_appspace",
          "read_appspace"
       ],
       "9b74f996-9136-4553-b5be-3dee06ee91fd":[
          "write_appspace",
          "read_appspace"
       ],
       "875ec30a-e44b-40ee-bb56-7aa05308078f":[
          "delete_appspace",
          "write_appspace",
          "read_appspace"
       ],
       "c0f59b9b-ad39-4c5b-9ad5-d6441f3a4868":[
          "read_appspace"
       ],
       "58d8bf72-4cc6-430f-810b-b7032e633f24":[
          "read_appspace"
       ],
       "360f0b1e-44d8-42b3-b013-fbc5b725699e":[
          "read_appspace"
       ]
    }


Find Objects and Groups that refer to a particular user: GET /users/*user_id*
------------------------------------------------------------------------------------

===============  ===================================
HTTP Method      GET
URI              /users/*user_id*
Request Format   N/A
Response Format  As below
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
===============  ===================================

The response for this request is something like::

    GET /users/572be387-b3e2-446f-a34a-ac5967685706
    Host: internal.vcap.acm.com
    Accept: application/json
    Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==

    HTTP/1.1 200 OK
    Content-Type: application/json

    {
       "id":"572be387-b3e2-446f-a34a-ac5967685706",
       "groups":[
          "25d9933c-d8fb-4a72-8791-1e94bc2ce7eb",
          "6a9969ac-fa9a-4d28-9fe2-a3a6bc930211"
       ],
       "objects":[
          "b6f80ef2-4fca-47e2-88f6-323d0db78472",
          "fcf363c8-5365-49cc-8284-e371e97ecd5d"
       ]
    }


Add a set of permissions for a subject to an object: PUT /objects/*object_id*/acl?id=*subject*&p=*permission1*,*permission2*
-----------------------------------------------------------------------------------------------------------------------------

Adds a subject *subject_id* to an ace for each permission *permission* on the object *object_id*.

===============  ==================================================
HTTP Method      PUT
URI              /objects/*object_id*/acl?id=*subject*&p=*permission1*,*permission2*
Request Format   N/A
Response Format  Refer to the `Object Schema`_
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ==================================================

For example::

    PUT /objects/11c32e98-e9e4-43ca-8ac4-164ecbcb71b1/access?id=dc06aceb-ecde-45a4-ba96-7a7fbd866902&p=read_appspace,write_appspace,delete_appspace
    Host: internal.vcap.acm.com
    Accept: application/json
    Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==

    HTTP/1.1 200 OK
    Content-Type: application/json

    {
       "name":"www_staging",
       "permission_sets":[
          "app_space"
       ],
       "id":"11c32e98-e9e4-43ca-8ac4-164ecbcb71b1",
       "additional_info":"{component => cloud_controller}",
       "acl":{
          "read_appspace":[
             "g-d0f42b1e-6d5b-4ea3-a15b-59c7320ec477",
             "dc06aceb-ecde-45a4-ba96-7a7fbd866902",
             "b3e5a4b8-39cb-4bbf-9884-94ba7a8b6eee",
             "8cbcbf18-4ec9-40ce-a2af-058377c8c2b7",
             "e2803726-5f04-4754-9f6c-c22fe27f4f92"
          ],
          "write_appspace":[
             "g-a0c16b18-8f66-4b2f-aa9a-ce590eeed13c",
             "8cbcbf18-4ec9-40ce-a2af-058377c8c2b7",
        	 "dc06aceb-ecde-45a4-ba96-7a7fbd866902"
          ],
          "delete_appspace":[
             "dc06aceb-ecde-45a4-ba96-7a7fbd866902"
          ]
       },
       "meta":{
          "created":"2011-11-29 17:18:47 -0800",
          "updated":"2011-11-29 17:18:47 -0800",
          "schema":"urn:acm:schemas:1.0"
       }
    }


Remove a set of permissions for a subject from an object: DELETE /objects/*object_id*/acl?id=*subject*&p=*permission1*,*permission2*
-----------------------------------------------------------------------------------------------------------------------------

Removes the specified permissions for the subject *subject* on the object *object_id*

===============  ==================================================
HTTP Method      DELETE
URI              /objects/*object_id*/acl?id=*subject*&p=*permission1*,*permission2*
Request Format   N/A
Response Format  Refer to the `Object Schema`_
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ==================================================

For example::

    DELETE /objects/11c32e98-e9e4-43ca-8ac4-164ecbcb71b1/access?id=dc06aceb-ecde-45a4-ba96-7a7fbd866902&p=delete_appspace
    Host: internal.vcap.acm.com
    Accept: application/json
    Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==

    HTTP/1.1 200 OK
    Content-Type: application/json

    {
       "name":"www_staging",
       "permission_sets":[
          "app_space"
       ],
       "id":"11c32e98-e9e4-43ca-8ac4-164ecbcb71b1",
       "additional_info":"{component => cloud_controller}",
       "acl":{
          "read_appspace":[
             "g-d0f42b1e-6d5b-4ea3-a15b-59c7320ec477",
             "b3e5a4b8-39cb-4bbf-9884-94ba7a8b6eee",
             "8cbcbf18-4ec9-40ce-a2af-058377c8c2b7",
             "e2803726-5f04-4754-9f6c-c22fe27f4f92"
          ],
          "write_appspace":[
             "g-a0c16b18-8f66-4b2f-aa9a-ce590eeed13c",
             "8cbcbf18-4ec9-40ce-a2af-058377c8c2b7"
          ],
          "delete_appspace":[
             "dc06aceb-ecde-45a4-ba96-7a7fbd866902"
          ]
       },
       "meta":{
          "created":"2011-11-29 17:18:47 -0800",
          "updated":"2011-11-29 17:18:47 -0800",
          "schema":"urn:acm:schemas:1.0"
       }
    }



Delete Object: DELETE /objects/*id*
------------------------------------------------------------------------------------

Deletes an object

===============  ===================================
HTTP Method      DELETE
URI              /objects/*id*
Request Format   N/A
Response Format  N/A
Response Codes   | 200 - Operation was successful
                 | 401 - Not authorized
                 | 404 - Not found                 
===============  ===================================


Operations on Groups
==================================

Group Schema
--------------------------------

Attributes

======================= ==============  ===================================
Property                Type            Description
======================= ==============  ===================================
id                      string          immutable identifier (ignored if included in a request). 
                                        It is returned in the response.
name                    string          name of this group
additional_info         object          additional information for this user group
members                 Array[string]   set of user ids of members of this group
meta                    object          meta information about this entity
======================= ==============  ===================================

Example::

    {
       "id":"54947df8-0e9e-4471-a2f9-9af509fb5889",
       "additional_info": {"org":"vmware", "name":"www-developers"},
       "members": [123268, 245424, 335111, 930290, 123055],
       "meta":{
          "updated":1273740902,
          "created":1273726800,
          "schema":"urn:acm:schemas:1.0"
       }
    }



Create Group: POST /groups
------------------------------------------------------------------------------------

Creates a group

===============  ===================================
HTTP Method      POST
URI              /groups
Request Format   Refer to the `Group Schema`_
Response Format  Refer to the `Group Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
===============  ===================================


Update Group: PUT /groups/*id*
------------------------------------------------------------------------------------

Updates a group

===============  ===================================
HTTP Method      PUT
URI              /groups/*id*
Request Format   Refer to the `Group Schema`_
Response Format  Refer to the `Group Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found                 
===============  ===================================

Replaces all the properties of a group. The "id" property is ignored.

Add a user to a group: PUT /groups/*id*/members/*user_id*
------------------------------------------------------------------------------------

Adds the user with the id *user_id* to the group *id*

===============  ===================================
HTTP Method      PUT
URI              /groups/*id*/members/*user_id*
Request Format   N/A
Response Format  Refer to the `Group Schema`_
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================


Remove a user from a group: DELETE /groups/*id*/members/*user_id*
------------------------------------------------------------------------------------

Removes the user with the id *user_id* from the group *id*

===============  ===================================
HTTP Method      DELETE
URI              /groups/*id*/members/*user_id*
Request Format   N/A
Response Format  Refer to the `Group Schema`_
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================


Get Group: GET /groups/*id*
------------------------------------------------------------------------------------

Gets a group

===============  ===================================
HTTP Method      GET
URI              /groups/*id*
Request Format   N/A
Response Format  Refer to the `Group Schema`_ 
Response Codes   | 200 - Operation was successful
                 | 400 - Bad request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================

The service responds with the json representation of the group. To request specific versions of the 
group schema, see "Versioning of Resource Representations".


Delete Group: DELETE /groups/*id*
------------------------------------------------------------------------------------

Deletes a group

===============  ===================================
HTTP Method      DELETE
URI              /groups/*id*
Request Format   N/A
Response Format  N/A
Response Codes   | 200 - Operation was successful
                 | 401 - Not authorized
===============  ===================================

Deleting a group causes the group to be removed from all existing ACEs in any referencing
objects.


Access Control Checks
=======================

Check Access: GET /objects/*id*/access?id=*subject*&p=*permission1*,*permission2*
--------------------------------------------------------------------------------------------------------------------------------

Checks Access of a subject (user/group) to an object

===============  ===================================
HTTP Method      GET
URI              /objects/*id*/access?id=*subject*&p=*permission1*,*permission2*
Request Format   N/A
Response Format  See below
Response Codes   | 200 - Operation was successful
                 | 400 - Bad Request
                 | 401 - Not authorized
                 | 404 - Not found
===============  ===================================

If access is permitted for the subject on the object for each permission, HTTP 200
is returned, else HTTP 401 is returned


Batch Check Access: POST /objects/access
----------------------------------------------------------

Checks Access of a group of subjects (user/group) and ACM objects

===============  ===================================
HTTP Method      POST
URI              /objects/access
Request Format   See below
Response Format  See below
Response Codes   | 200 - Operation was successful
                 | 401 - Not authorized
===============  ===================================

Request format:: 

    [
        {
            "id": "subject1",
            "p": ["permission1", "permission2", ...]
        },
        {
            "id": "subject2",
            "p": ["permission1", "permission3", ...]
        }
    ]

Response format::

    [
        {
            "id": "subject1",
            "response": "false"
        },
        {
            "id": "subject2",
            "response": "true"
        }
    ]


Check Permissions: GET /objects/*id*/acl/*subject*
--------------------------------------------------------------------------------------------------------------

Gets the permission set for the subject (user/group) on an object

===============  ===================================
HTTP Method      GET
URI              /objects/*id*/acl/*subject*
Request Format   N/A
Response Format  N/A
Response Codes   | 200 - Operation was successful
                 | 401 - Not authorized
===============  ===================================

The method will return the following response if the subject (user/group) has some permissions on the
object::

    {
        "permissions": ["permission1", "permission2", ...]
    }

If the subject does not have a permission, the API will return the following-:

    {
        "permissions": [ ]
    }


Batch Check Permissions: POST /objects/permissions
----------------------------------------------------------------------------------

Gets the permission set for a set of subjects (user/group) on a set of objects

===============  ===================================
HTTP Method      POST
URI              /objects/permissions
Request Format   See below
Response Format  See below
Response Codes   | 200 - Operation was successful
                 | 401 - Not authorized
===============  ===================================

Request format:: 

    [
        {
            "id": "object_id1",
            "subject": "subject_id1"
        },
        {
            "id": "object_id2",
            "subject": "subject_id2"
        }
    ]

Response format::

    [
        {
            "id": "object_id1",
            "permissions": ["permission1", "permission2"]
        },
        {
            "id": "object_id2",
            "permissions": [ ]
        }
    ]


Example Requests and Responses
===============================

Partial Updates to an Object: Delete User from ACL
----------------------------------------------------

First get the whole object so we can inspect it and verify that the user is referenced in the acl:

::

    GET /objects/54947df8-0e9e-4471-a2f9-9af509fb5889
    Host: internal.vcap.acm.com
    Accept: application/json
    Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==

    HTTP/1.1 200 OK
    Content-Type: application/json
    ETag: "f250dd84f0671c3"
    
    {
       "permissionSets":["app_space"],
       "id":"54947df8-0e9e-4471-a2f9-9af509fb5889",
       "additional_info": {
          "org":"vmware", "name":"www_staging",
       },
       "acl":{
          "read_app":[
             "3749285",
             "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
          ],
          "update_app":[
             "3749285",
             "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
          ],
          "read_app_logs":[
             "3749285",
             "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66",
             "g-d1682c64-040f-4511-85a9-62fcff3cbbe2"
          ],
          "read_service":[
             "3749285",
             "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
          ],
          "write_service":[
             "3749285",
             "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
          ]
       },
       "meta":{
          "updated":1273740902,
          "created":1273726800,
          "schema":"urn:acm:schemas:1.0"
       }
    }


Now PUT the change including only the "acl" object:

.. DS: an ACL might be quite large, in this example we have to add a
.. permission set for all permissions, but in general could we add
.. only the ones that changed?  Or is that too complicated?  I'm
.. thinking we might need to allow a PUT to
.. /objects/{object_id}/access instead.

.. DO: Agreed. See long note at the end of the `partial update`_ 
.. section. WDYT?

.. JD: Agreed. We'll implement that for now to make the feature
.. available and evaluate the feedback. We can implement the rest
.. after the initial integration.

::

   PUT /objects/54947df8-0e9e-4471-a2f9-9af509fb5889
   Host: internal.vcap.acm.com
   Accept: application/json
   Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==
   ETag: "a330bc54f0671c9"
   X-HTTP-Method-Override: PATCH

   {
     "acl":{
        "read_app":[
          "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
        ],
        "update_app":[
          "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
        ],
        "read_app_logs":[
          "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66",
          "g-d1682c64-040f-4511-85a9-62fcff3cbbe2"
        ],
        "read_service":[
          "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
        ],
        "write_service":[
          "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
        ]
     }
   }
   
   
   HTTP/1.1 200 OK
   Content-Type: application/json
   Location: http://internal.vcap.acm.com/objects/54947df8-0e9e-4471-a2f9-9af509fb5889
   ETag: "f250dd84f0671c3"
   
   {
      "permission sets":["app_space"],
       "id":"54947df8-0e9e-4471-a2f9-9af509fb5889",
       "additional_info": {
          "org":"vmware", "name":"www_staging",
       },
      "acl":{
          "read_app":[
             "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
          ],
          "update_app":[
             "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
          ],
          "read_app_logs":[
             "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66",
             "g-d1682c64-040f-4511-85a9-62fcff3cbbe2"
          ],
          "read_service":[
             "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
          ],
          "write_service":[
             "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
          ]
       },
       "meta":{
          "updated":1273740902,
          "created":1273726800,
          "schema":"urn:acm:schemas:1.0"
      }
    }


Delete a Permission from an Object's ACL
------------------------------------------

.. DS: I changed the HTTP method to DELETE (assume it was a typo?)

.. DO: I changed it back, the example showing a partial update of an object
.. which deletes a portion of the ACL, just those using a specific permission.

.. DO: my concern with this example is that I can't imagine what use case it
.. serves. I don't know why someone would delete all ACEs for a specific 
.. permission from an ACL. Perhaps we could rewrite or add an example that 
.. shows how remove all permission for a specific user -- in an easier way
.. than the example above.

.. JD: It's just an example of how you could achieve such functionality.
.. You might have a use-case where you may want to remove update_app rights
.. from the app space completely. I'll look for a better example though.

::

   PUT /objects/54947df8-0e9e-4471-a2f9-9af509fb5889
   Host: internal.vcap.acm.com
   Accept: application/json
   Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==
   ETag: "a330bc54f0671c9"
   X-HTTP-Method-Override: PATCH

   {
       "acl": {
          "update_app": { }
       }
   }
   
   
   HTTP/1.1 200 OK
   Content-Type: application/json
   Location: http://internal.vcap.acm.com/objects/54947df8-0e9e-4471-a2f9-9af509fb5889
   ETag: "f250dd84f0671c3"
   
   {
     "permissionSets":["app_space"],
     "id":"54947df8-0e9e-4471-a2f9-9af509fb5889",
     "additional_info":{
        "org":"vmware", "name":"www_staging",
     },
     "acl":{
        "read_app":[
          "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
        ],
        "read_app_logs":[
          "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66",
          "g-d1682c64-040f-4511-85a9-62fcff3cbbe2"
        ],
        "read_service":[
          "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
        ],
        "write_service":[
          "g-4a9a8c60-0cb2-11e1-be50-0800200c9a66"
        ]
      },
      "meta":{
        "updated":1273740902,
        "created":1273726800,
        "schema":"urn:acm:schemas:1.0"
     }
   }


Open Issues
=============

- Return codes need to be looked at again. Need to update return codes for operation failures.

- it has been suggested that we support some notion of context in the authorization decision, e.g. be able to
  support that this permission is granted to to this user if the user is also the 'owner' of the resource. 

- May also want to support some relationships between objects so that there can be some inheritance of
  ACLs. 

- Even without inheritance of ACLs, some notion of relationships/containment between objects and groups could 
  be very useful and not require the client to implement it. 
