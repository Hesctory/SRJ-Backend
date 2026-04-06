namespace SRJBackend.Application.DTOs;

public class UserDTO
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string Phone { get; set; } = null!;
    public List<string> Roles { get; set; } = new List<string>();
}
