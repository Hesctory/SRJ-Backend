namespace SRJBackend.Domain.Entities;

public class DUser
{
    public int Id { get; private set; }
    public string? FullName { get; private set; }
    public string? Email { get; private set; }
    public string? Phone { get; private set; }
    public bool? IsActive { get; private set; }
    public List<string> Roles { get; private set; }

    public DUser(int id, string? fullName, string? email, string? phone, bool? isActive, List<string> roles)
    {
        Id = id;
        FullName = fullName;
        Email = email;
        Phone = phone;
        IsActive = isActive;
        Roles = roles;
    }
}
