# Complete Annotations Guide for Ecommerce Project

## Spring Framework Annotations

### Core Spring Annotations
- **@Component**: Marks a class as a Spring-managed component
- **@Service**: Specialization of @Component for service layer classes
- **@Repository**: Specialization of @Component for data access layer classes
- **@Controller**: Marks a class as a Spring MVC controller
- **@RestController**: Combines @Controller + @ResponseBody for REST APIs

### Dependency Injection
- **@Autowired**: Automatic dependency injection (field/setter/constructor)
- **@RequiredArgsConstructor**: Lombok annotation for constructor injection of final fields
- **@Qualifier**: Specifies which bean to inject when multiple candidates exist

### Web MVC Annotations
- **@RequestMapping**: Maps HTTP requests to handler methods (class/method level)
- **@GetMapping**: Maps HTTP GET requests to handler methods
- **@PostMapping**: Maps HTTP POST requests to handler methods
- **@PutMapping**: Maps HTTP PUT requests to handler methods
- **@DeleteMapping**: Maps HTTP DELETE requests to handler methods
- **@PathVariable**: Binds URI template variables to method parameters
- **@RequestBody**: Binds HTTP request body to method parameter object
- **@RequestParam**: Binds HTTP request parameters to method parameters
- **@ResponseBody**: Indicates method return value should be bound to web response body

### Configuration Annotations
- **@Configuration**: Indicates class contains Spring configuration
- **@Bean**: Indicates method produces a bean managed by Spring container
- **@Value**: Injects values from properties files
- **@ConfigurationProperties**: Binds external configuration to Java objects

## Security Annotations

### Method-Level Security
- **@PreAuthorize**: Checks authorization before method execution
  - Example: `@PreAuthorize("hasRole('ADMIN')")`
  - Example: `@PreAuthorize("hasRole('USER') or hasRole('ADMIN')")`
- **@PostAuthorize**: Checks authorization after method execution
- **@Secured**: Simple role-based security (legacy)
- **@RolesAllowed**: JSR-250 annotation for role-based security

### Class-Level Security
- **@EnableGlobalMethodSecurity**: Enables method-level security
- **@EnableWebSecurity**: Enables Spring Security web security

## Validation Annotations (Jakarta Validation)

### Basic Validation
- **@Valid**: Triggers validation on method parameters/return values
- **@Validated**: Enables method-level validation on classes

### Field Validation Constraints
- **@NotNull**: Field cannot be null
- **@NotEmpty**: Collection/array/string cannot be null or empty
- **@NotBlank**: String cannot be null, empty, or whitespace-only
- **@Size**: Validates size of string/collection/array
  - Example: `@Size(min = 2, max = 50)`
- **@Min**: Minimum value for numbers
  - Example: `@Min(value = 1, message = "Must be at least 1")`
- **@Max**: Maximum value for numbers
- **@Positive**: Number must be greater than 0
- **@PositiveOrZero**: Number must be greater than or equal to 0
- **@Negative**: Number must be less than 0
- **@Email**: Validates email format
- **@Pattern**: Validates against regular expression
  - Example: `@Pattern(regexp = "^[0-9]{10}$", message = "Phone must be 10 digits")`

### Custom Validation Messages
All validation annotations support custom messages:
```java
@NotNull(message = "Product ID is required")
@Positive(message = "Product ID must be positive")
private Long productId;
```

## JPA/Hibernate Annotations

### Entity Mapping
- **@Entity**: Marks class as JPA entity
- **@Table**: Specifies database table name and properties
  - Example: `@Table(name = "users", uniqueConstraints = @UniqueConstraint(columnNames = "email"))`
- **@Id**: Marks primary key field
- **@GeneratedValue**: Specifies primary key generation strategy
  - Example: `@GeneratedValue(strategy = GenerationType.IDENTITY)`
- **@Column**: Maps field to database column with properties
  - Example: `@Column(name = "user_name", nullable = false, length = 50)`

### Relationship Mapping
- **@OneToOne**: One-to-one relationship
  - Example: `@OneToOne(cascade = CascadeType.ALL, fetch = FetchType.LAZY)`
- **@OneToMany**: One-to-many relationship
  - Example: `@OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)`
- **@ManyToOne**: Many-to-one relationship
  - Example: `@ManyToOne(fetch = FetchType.LAZY)`
- **@ManyToMany**: Many-to-many relationship
- **@JoinColumn**: Specifies foreign key column
  - Example: `@JoinColumn(name = "user_id", nullable = false)`
- **@JoinTable**: Specifies join table for many-to-many relationships

### Fetch and Cascade Options
- **FetchType.LAZY**: Load related entities on demand
- **FetchType.EAGER**: Load related entities immediately
- **CascadeType.ALL**: Cascade all operations
- **CascadeType.PERSIST**: Cascade persist operations
- **CascadeType.MERGE**: Cascade merge operations
- **CascadeType.REMOVE**: Cascade remove operations

### Enumeration Mapping
- **@Enumerated**: Maps enum fields to database
  - Example: `@Enumerated(EnumType.STRING)` or `@Enumerated(EnumType.ORDINAL)`

## Lombok Annotations

### Code Generation
- **@Data**: Generates getters, setters, toString, equals, hashCode
- **@Getter**: Generates getter methods
- **@Setter**: Generates setter methods
- **@ToString**: Generates toString method
- **@EqualsAndHashCode**: Generates equals and hashCode methods

### Constructor Generation
- **@NoArgsConstructor**: Generates no-argument constructor
- **@AllArgsConstructor**: Generates constructor with all fields
- **@RequiredArgsConstructor**: Generates constructor for final/non-null fields

### Builder Pattern
- **@Builder**: Generates builder pattern implementation
- **@SuperBuilder**: Builder pattern with inheritance support

### Utility Annotations
- **@ToString.Exclude**: Excludes field from toString method (prevents circular references)
- **@EqualsAndHashCode.Exclude**: Excludes field from equals/hashCode
- **@Slf4j**: Generates SLF4J logger field

## Transaction Annotations

### Spring Transaction Management
- **@Transactional**: Marks method/class as transactional
  - Example: `@Transactional(readOnly = true)`
  - Example: `@Transactional(rollbackFor = Exception.class)`
- **@EnableTransactionManagement**: Enables annotation-driven transaction management

### Transaction Properties
- **propagation**: Transaction propagation behavior
- **isolation**: Transaction isolation level
- **readOnly**: Optimization hint for read-only transactions
- **rollbackFor**: Exceptions that trigger rollback
- **noRollbackFor**: Exceptions that don't trigger rollback

## Caching Annotations

### Spring Cache Abstraction
- **@Cacheable**: Caches method result
- **@CacheEvict**: Removes entries from cache
- **@CachePut**: Updates cache with method result
- **@Caching**: Groups multiple cache annotations
- **@EnableCaching**: Enables annotation-driven caching

## Testing Annotations

### Spring Boot Test
- **@SpringBootTest**: Loads complete Spring application context for testing
- **@WebMvcTest**: Tests Spring MVC components only
- **@DataJpaTest**: Tests JPA repositories only
- **@MockBean**: Creates mock beans in Spring context
- **@TestConfiguration**: Test-specific configuration

### JUnit 5
- **@Test**: Marks test methods
- **@BeforeEach**: Runs before each test method
- **@AfterEach**: Runs after each test method
- **@BeforeAll**: Runs once before all test methods
- **@AfterAll**: Runs once after all test methods

## Project-Specific Usage Examples

### Controller Security Pattern
```java
@RestController
@RequestMapping("/api/orders")
@RequiredArgsConstructor
@Validated
@PreAuthorize("hasRole('USER') or hasRole('ADMIN')")
public class OrderController {
    
    @GetMapping("/my")
    public ResponseEntity<List<OrderDTO>> getMyOrders() {
        // Implementation
    }
    
    @PostMapping
    public ResponseEntity<OrderDTO> createOrder(@Valid @RequestBody CreateOrderRequest request) {
        // Implementation
    }
}
```

### Entity Relationship Pattern
```java
@Entity
@Table(name = "users")
@Data
@NoArgsConstructor
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    @ToString.Exclude
    private List<Order> orders = new ArrayList<>();
}
```

### DTO Validation Pattern
```java
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateOrderRequest {
    @NotNull(message = "User ID is required")
    @Positive(message = "User ID must be positive")
    private Long userId;
    
    @NotEmpty(message = "Order items are required")
    @Valid
    private List<OrderItemRequest> items;
}
```

This comprehensive guide covers all annotations used in the ecommerce project, providing context and examples for proper usage.