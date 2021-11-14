C - POST create a resource from server
R - GET get a resource from server
U - PUT/PATCH update a resource in server
    --PUT（UPDATE）：在服务器更新资源（客户端提供完整资源数据）
    --PATCH（UPDATE）：在服务器更新资源（客户端提供需要修改的资源数据）
D - DELETE delete a resource in server


HTTP方法选择
这部分非常简单，前面说了，URI中不包含动词，具体行为是有HTTP方法描述的，而用来对资源进行CRUD的方法无外乎以下四种：

GET：查询操作。特点是安全且幂等。安全是指不会对服务端资源进行任何修改，幂等是指多次执行产生的结果是一样的。
POST：创建新资源。不安全、不幂等。
PUT：更新或创建新资源。不安全、幂等。
DELETE：删除资源。不安全、幂等。
当然HTTP还有其它方法，但在RESTful API中使用很少，这里不讨论了。这里有两个问题需要注意。

一个是有一个特殊情况就是如果查询的参数非常多，或者有敏感数据，可以使用POST实现查询，比如很多DSL查询都走的是POST，但也有走GET的，比如ElasticSearch的DSL查询同时支持GET和POST。

另外一个是上面有个细节不知道大家注意到没有：POST和PUT都能用于创建新资源，那有什么区别呢？

当客户端能够决定资源最终的URI时（其实就是决定资源的唯一标识符时），可以使用PUT；如果不能，就使用POST。比如我们要创建一个新的订单，如果客户端可以决定（需要服务端支持）订单ID，那可以使用PUT操作：

PUT http://example.com/orders/1
如果客户端决定不了，需要服务端自己生成，那就使用POST：

// 格式1
POST http://example.com/orders
// 格式2
POST http://example.com/orders/1
注意一下上面的格式2，也是有这种形式的，此时那个1仅是客户端给服务端的建议，服务端未必会采纳。

所以，为了让你的API更加RESTful，请只在客户端能够决定资源ID的时候，才使用PUT创建新资源，或者表达“不存在就创建，存在就更新”的语义的时候才使用PUT操作，否则请使用POST创建新资源。

下面给一些例子：

// 查询所有订单
GET http://example.com/orders
// 查询某个订单
GET http://example.com/orders/{id}
// 创建一个或多个订单（如果有批量创建的需求，可以分两个URI。个人建议使用一个URI，然后支持1~n个资源对象）
POST http://example.com/orders
// 修改一个订单
PUT http://example.com/orders/{id}
// 修改多个订单
PUT http://example.com/orders/{id1},{id2},{id3}
// 删除一个订单
DELETE http://example.com/orders/{id}
// 删除多个订单
DELETE http://example.com/orders/{id1},{id2},{id3}
// 删除所有订单
DELETE http://example.com/orders












2.1. Use nouns to represent resources
RESTful URI should refer to a resource that is a thing (noun) instead of referring to an action (verb) because nouns have properties that verbs do not have – similarly, resources have attributes. Some examples of a resource are:

Users of the system
User Accounts
Network Devices etc.
and their resource URIs can be designed as below:

http://api.example.com/device-management/managed-devices 
http://api.example.com/device-management/managed-devices/{device-id} 
http://api.example.com/user-management/users
http://api.example.com/user-management/users/{id}
For more clarity, let’s divide the resource archetypes into four categories (document, collection, store, and controller). Then it would be best if you always targeted to put a resource into one archetype and then use its naming convention consistently.


https://restfulapi.net/resource-naming/

1.1. Singleton and Collection Resources
A resource can be a singleton or a collection.

For example, “customers” is a collection resource and “customer” is a singleton resource (in a banking domain).

We can identify “customers” collection resource using the URI “/customers“. We can identify a single “customer” resource using the URI “/customers/{customerId}“.

1.2. Collection and Sub-collection Resources
A resource may contain sub-collection resources also.

For example, sub-collection resource “accounts” of a particular “customer” can be identified using the URN “/customers/{customerId}/accounts” (in a banking domain).

Similarly, a singleton resource “account” inside the sub-collection resource “accounts” can be identified as follows: “/customers/{customerId}/accounts/{accountId}“.




2.1.1. document
A document resource is a singular concept that is akin to an object instance or database record.

In REST, you can view it as a single resource inside resource collection. A document’s state representation typically includes both fields with values and links to other related resources.

Use “singular” name to denote document resource archetype.

http://api.example.com/device-management/managed-devices/{device-id}
http://api.example.com/user-management/users/{id}
http://api.example.com/user-management/users/admin


2.1.4. controller
A controller resource models a procedural concept. Controller resources are like executable functions, with parameters and return values, inputs, and outputs.

Use “verb” to denote controller archetype.

http://api.example.com/cart-management/users/{id}/cart/checkout http://api.example.com/song-management/users/{id}/playlist/play


2.2.4. Do not use underscores ( _ )
It’s possible to use an underscore in place of a hyphen to be used as a separator – But depending on the application’s font, it is possible that the underscore (_) character can either get partially obscured or completely hidden in some browsers or screens.

To avoid this confusion, use hyphens (-) instead of underscores ( _ ).

http://api.example.com/inventory-management/managed-entities/{id}/install-script-location  //More readable

http://api.example.com/inventory-management/managedEntities/{id}/installScriptLocation  //Less readable
2.2.5. Use lowercase letters in URIs
When convenient, lowercase letters should be consistently preferred in URI paths.

http://api.example.org/my-folder/my-doc       //1
HTTP://API.EXAMPLE.ORG/my-folder/my-doc     //2
http://api.example.org/My-Folder/my-doc       //3
In the above examples, 1 and 2 are the same but 3 is not as it uses My-Folder in capital letters.


2.3. Do not use file extensions
File extensions look bad and do not add any advantage. Removing them decreases the length of URIs as well. No reason to keep them.

Apart from the above reason, if you want to highlight the media type of API using file extension, then you should rely on the media type, as communicated through the Content-Type header, to determine how to process the body’s content.

http://api.example.com/device-management/managed-devices.xml  /*Do not use it*/

http://api.example.com/device-management/managed-devices 	/*This is correct URI*/
2.4. Never use CRUD function names in URIs
We should not use URIs to indicate a CRUD function. URIs should only be used to uniquely identify the resources and not any action upon them.

We should use HTTP request methods to indicate which CRUD function is performed.

HTTP GET http://api.example.com/device-management/managed-devices  //Get all devices
HTTP POST http://api.example.com/device-management/managed-devices  //Create new Device

HTTP GET http://api.example.com/device-management/managed-devices/{id}  //Get device for given Id
HTTP PUT http://api.example.com/device-management/managed-devices/{id}  //Update device for given Id
HTTP DELETE http://api.example.com/device-management/managed-devices/{id}  //Delete device for given Id
2.5. Use query component to filter URI collection
Often, you will encounter requirements where you will need a collection of resources sorted, filtered, or limited based on some specific resource attribute.

For this requirement, do not create new APIs – instead, enable sorting, filtering, and pagination capabilities in resource collection API and pass the input parameters as query parameters. e.g.

http://api.example.com/device-management/managed-devices
http://api.example.com/device-management/managed-devices?region=USA
http://api.example.com/device-management/managed-devices?region=USA&brand=XYZ
http://api.example.com/device-management/managed-devices?region=USA&brand=XYZ&sort=installation-date
