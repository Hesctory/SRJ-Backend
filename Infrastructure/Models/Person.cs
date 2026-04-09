using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Person
{
    public int Id { get; set; }

    public string Names { get; set; } = null!;

    public string PaternalLastname { get; set; } = null!;

    public string MaternalLastname { get; set; } = null!;

    public int GenderId { get; set; }

    public DateOnly BirthDate { get; set; }

    public int DocumentTypeId { get; set; }

    public string IdDocumentNumber { get; set; } = null!;

    public string Address { get; set; } = null!;

    public int AddressUbigeoId { get; set; }

    public string? Email { get; set; }

    public string? LandlinePhone { get; set; }

    public string? CellPhone { get; set; }

    public virtual Ubigeo AddressUbigeo { get; set; } = null!;

    public virtual DocumentType DocumentType { get; set; } = null!;

    public virtual EducationalPerson? EducationalPerson { get; set; }

    public virtual Gender Gender { get; set; } = null!;
}
