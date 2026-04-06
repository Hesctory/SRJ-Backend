using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class User
{
    public int Id { get; set; }

    public string Names { get; set; } = null!;

    public string PaternalLastname { get; set; } = null!;

    public string MaternalLastname { get; set; } = null!;

    public string Email { get; set; } = null!;

    public string HashedPassword { get; set; } = null!;

    public string Phone { get; set; } = null!;

    public bool IsActive { get; set; }

    public virtual ICollection<Role> Roles { get; set; } = new List<Role>();
}
