using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class District
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public int ProvinceId { get; set; }

    public string Code { get; set; } = null!;

    public virtual Province Province { get; set; } = null!;

    public virtual Ubigeo? Ubigeo { get; set; }
}
